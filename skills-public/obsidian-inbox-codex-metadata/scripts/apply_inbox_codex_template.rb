#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"
require "pathname"
require "set"
require "time"
require "date"
require "uri"
require "yaml"

DEFAULT_TARGET = Pathname.new("/Users/kyoheinogami/Library/Mobile Documents/iCloud~md~obsidian/Documents/OBSIDIAN DRIVE/10_CAPTURE/inbox-codex")
DEFAULT_TEMPLATE = Pathname.new("/Users/kyoheinogami/Library/Mobile Documents/iCloud~md~obsidian/Documents/OBSIDIAN DRIVE/99_SYSTEM/Templates/Basic_Template.md")
EMPTY_AS_BLANK_KEYS = %w[aliases context type_mbti linter-yaml-title-alias source origin domain updated].freeze
KEYWORD_DOMAIN_JOB = %w[codex chatgpt claude openai cursor git github vscode obsidian plugin yaml metadata template prompt ai automation research].freeze
KEYWORD_DOMAIN_INFO = %w[vault frontmatter property properties tag tags zettel moc tasknotes folder structure schema taxonomy].freeze
KEYWORD_DOMAIN_SELF = %w[health hobby entertainment anime manga movie music life personal private reflection fitness].freeze
TAG_RULES = [
  [%w[codex], "ai/agent/codex"],
  [%w[git github], "git/github"],
  [%w[vscode], "vscode"],
  [%w[obsidian], "obsidian"]
].freeze

def split_frontmatter(text)
  lines = text.lines
  return [nil, text] unless lines.first&.strip == "---"

  closing_index = lines[1..]&.index { |line| line.strip == "---" }
  return [nil, text] unless closing_index

  frontmatter = lines[1, closing_index].join
  body = lines[(closing_index + 2)..]&.join.to_s
  [frontmatter, body]
end

def template_key_order(template_path)
  frontmatter, = split_frontmatter(File.read(template_path))
  raise "Template frontmatter was not found: #{template_path}" unless frontmatter

  keys = []
  frontmatter.each_line do |line|
    key = line[/\A([A-Za-z0-9_-]+):/, 1]
    keys << key if key
  end

  raise "Template frontmatter did not contain any top-level keys: #{template_path}" if keys.empty?

  keys
end

def stringify_keys(value)
  case value
  when Hash
    value.each_with_object({}) do |(key, nested), acc|
      acc[key.to_s] = stringify_keys(nested)
    end
  when Array
    value.map { |item| stringify_keys(item) }
  else
    value
  end
end

def parse_frontmatter(frontmatter)
  return {} unless frontmatter

  parsed = YAML.safe_load(frontmatter, permitted_classes: [Date, Time], aliases: true) || {}
  parsed.is_a?(Hash) ? stringify_keys(parsed) : {}
rescue Psych::SyntaxError => e
  raise "Could not parse existing frontmatter: #{e.message}"
end

def clean_string(value)
  return nil if value.nil?

  string =
    case value
    when Time, DateTime
      value.strftime("%Y-%m-%d %H:%M")
    when Date
      value.strftime("%Y-%m-%d")
    else
      value.to_s
    end

  stripped = string.strip
  stripped.empty? ? nil : stripped
end

def normalize_source_value(value)
  source = clean_string(value)
  return nil if source == "current chat conversation"

  source
end

def clean_array(value)
  array =
    case value
    when nil
      []
    when Array
      value
    else
      [value]
    end

  array.each_with_object([]) do |item, acc|
    cleaned = clean_string(item)
    acc << cleaned unless cleaned.nil? || cleaned == "[[]]"
  end.uniq
end

def clean_aliases(value)
  case value
  when nil
    nil
  when Array
    cleaned = clean_array(value)
    cleaned.empty? ? nil : cleaned
  else
    clean_string(value)
  end
end

def first_url(body)
  url = URI::DEFAULT_PARSER.extract(body, %w[http https]).first
  return nil unless url

  url.sub(/[)\],.;:]+\z/, "")
end

def codex_like?(title, body)
  haystack = [title, body].compact.join("\n").downcase
  haystack.include?("codex")
end

def academic_like?(title, body, source)
  haystack = [title, body, source].compact.join("\n").downcase
  haystack.match?(/jamanetwork|pubmed|meta-analysis|systematic review|abstract|doi|journal|paper/)
end

def keyword_match?(haystack, keyword)
  return false if haystack.nil? || keyword.nil?

  if keyword.match?(/\A[a-z0-9][a-z0-9_-]*\z/)
    haystack.match?(/(^|[^a-z0-9])#{Regexp.escape(keyword)}([^a-z0-9]|$)/)
  else
    haystack.include?(keyword)
  end
end

def stable_reference_like?(title, body, source)
  return false if source.nil?

  haystack = [title, body, source].compact.join("\n").downcase
  haystack.match?(/youtube|youtu\.be|wikipedia|paper|journal|article|guide|manual|documentation|news|review/) ||
    academic_like?(title, body, source)
end

def infer_domain(title, body, source)
  haystack = [title, body, source].compact.join("\n").downcase
  return "仕事勉強" if academic_like?(title, body, source)
  return "情報管理" if KEYWORD_DOMAIN_INFO.any? { |word| keyword_match?(haystack, word) } &&
    !KEYWORD_DOMAIN_JOB.any? { |word| keyword_match?(haystack, word) }
  return "仕事勉強" if KEYWORD_DOMAIN_JOB.any? { |word| keyword_match?(haystack, word) }
  return "自分自身" if KEYWORD_DOMAIN_SELF.any? { |word| keyword_match?(haystack, word) }

  "仕事勉強"
end

def infer_origin(source, title, body)
  return nil unless source || codex_like?(title, body)

  case source.to_s
  when /\Ahttps?:\/\/chatgpt\.com\/g\//
    "llm/gpt/project"
  when /\Ahttps?:\/\/chatgpt\.com\//
    "llm/gpt"
  when /\Ahttps?:\/\/(www\.)?youtube\.com\//, /\Ahttps?:\/\/youtu\.be\//
    "youtube"
  when /\Ahttps?:\/\/jamanetwork\.com\//
    "academic/jama"
  when /\Ahttps?:\/\/(pubmed|www\.ncbi\.nlm\.nih\.gov|ncbi\.nlm\.nih\.gov)\//
    "academic/pubmed"
  when /\Ahttps?:\/\/daigovideolab\.jp\//
    "dlabo/keigo"
  when /\Ahttps?:\/\/github\.com\//
    "github"
  else
    codex_like?(title, body) ? "llm/codex" : nil
  end
end

def infer_type(existing_type, title, body, source)
  return existing_type if existing_type

  stable_reference_like?(title, body, source) ? "resources" : "capture"
end

def infer_aliases(existing_aliases, title, body, source)
  return existing_aliases unless existing_aliases.nil? || (existing_aliases.respond_to?(:empty?) && existing_aliases.empty?)

  academic_like?(title, body, source) ? "論文" : nil
end

def infer_tags(existing_tags, title, body, source)
  return existing_tags unless existing_tags.empty?

  haystack = [title, body, source].compact.join("\n").downcase
  tags = []

  TAG_RULES.each do |keywords, tag|
    tags << tag if keywords.any? { |word| keyword_match?(haystack, word) }
  end

  if tags.include?("git/github") && haystack.match?(/\bgit\b|git\s*-/)
    tags << "git/command"
  end

  tags << "topic" if tags.empty? && academic_like?(title, body, source)
  tags.uniq.first(4)
end

def infer_context(existing_context, body)
  return existing_context unless existing_context.empty?

  links = body.scan(/\[\[([^\]]+)\]\]/).flatten.map(&:strip).reject(&:empty?).uniq
  links.first(3).map { |link| "[[#{link}]]" }
end

def safe_birthtime(stat)
  stat.birthtime
rescue NotImplementedError
  stat.mtime
end

def format_timestamp(time)
  time.getlocal.strftime("%Y-%m-%d %H:%M")
end

def id_prefix(type, source)
  return "TASK" if type == "task"
  return "PRJ" if type == "project"

  source ? "REF" : "NOTE"
end

def generated_id(existing_id, type, source, timestamp, used_ids)
  return existing_id if existing_id

  candidate_time = timestamp

  loop do
    candidate = "#{id_prefix(type, source)}-#{candidate_time.strftime("%Y%m%d-%H%M%S")}"
    unless used_ids.include?(candidate)
      used_ids << candidate
      return candidate
    end

    candidate_time += 1
  end
end

def simple_scalar?(value)
  value.is_a?(String) || value.is_a?(Numeric) || value == true || value == false
end

def plain_scalar?(value)
  return false if value.empty?
  return false if value =~ /\A[!&*{}\[\],>|%@`'"]/
  return false if value =~ /:\s/
  return false if value =~ /\A[?-]\s/
  return false if value =~ /\s#/
  return false if value =~ /[\[\]{}#\n]/

  true
end

def dump_scalar(value)
  return value.to_s if value.is_a?(Numeric) || value == true || value == false

  string = value.to_s
  return string if plain_scalar?(string)

  "\"#{string.gsub("\\", "\\\\").gsub("\"", "\\\"")}\""
end

def dump_value(key, value, indent = 0)
  pad = "  " * indent

  case value
  when nil
    "#{pad}#{key}:\n"
  when Hash
    lines = +"#{pad}#{key}:\n"
    value.each do |nested_key, nested_value|
      lines << dump_value(nested_key, nested_value, indent + 1)
    end
    lines
  when Array
    if value.empty?
      EMPTY_AS_BLANK_KEYS.include?(key) ? "#{pad}#{key}:\n" : "#{pad}#{key}: []\n"
    else
      lines = +"#{pad}#{key}:\n"
      value.each do |item|
        if simple_scalar?(item)
          lines << "#{pad}  - #{dump_scalar(item)}\n"
        elsif item.is_a?(Hash)
          first = true
          item.each do |nested_key, nested_value|
            prefix = first ? "#{pad}  - " : "#{pad}    "
            if nested_value.is_a?(Hash) || nested_value.is_a?(Array)
              lines << "#{prefix}#{nested_key}:\n"
              lines << dump_nested(nested_value, indent + 2)
            else
              lines << "#{prefix}#{nested_key}: #{dump_scalar(nested_value)}\n"
            end
            first = false
          end
        end
      end
      lines
    end
  else
    "#{pad}#{key}: #{dump_scalar(value)}\n"
  end
end

def dump_nested(value, indent)
  pad = "  " * indent

  case value
  when Hash
    value.each_with_object(+"") do |(nested_key, nested_value), acc|
      acc << dump_value(nested_key, nested_value, indent)
    end
  when Array
    value.each_with_object(+"") do |item, acc|
      if simple_scalar?(item)
        acc << "#{pad}- #{dump_scalar(item)}\n"
      elsif item.is_a?(Hash)
        first = true
        item.each do |nested_key, nested_value|
          prefix = first ? "#{pad}- " : "#{pad}  "
          if nested_value.is_a?(Hash) || nested_value.is_a?(Array)
            acc << "#{prefix}#{nested_key}:\n"
            acc << dump_nested(nested_value, indent + 1)
          else
            acc << "#{prefix}#{nested_key}: #{dump_scalar(nested_value)}\n"
          end
          first = false
        end
      end
    end
  else
    "#{pad}#{dump_scalar(value)}\n"
  end
end

def build_frontmatter(template_keys, existing, inferred)
  ordered = {}

  template_keys.each do |key|
    ordered[key] = inferred.key?(key) ? inferred[key] : existing[key]
  end

  existing.each do |key, value|
    next if ordered.key?(key)

    ordered[key] = value
  end

  ordered
end

def normalize_existing(existing)
  normalized = existing.dup
  %w[id title type status domain origin created updated type_mbti linter-yaml-title-alias].each do |key|
    normalized[key] = clean_string(normalized[key])
  end
  normalized["source"] = normalize_source_value(existing["source"])

  normalized["aliases"] = clean_aliases(existing["aliases"])
  normalized["tags"] = clean_array(existing["tags"])
  normalized["context"] = clean_array(existing["context"])
  normalized
end

def inferred_values(path, existing, body, stat, used_ids)
  normalized = normalize_existing(existing)
  title = normalized["title"] || path.basename(".md").to_s
  source = normalized["source"] || first_url(body)
  type = infer_type(normalized["type"], title, body, source)
  created_time = safe_birthtime(stat)
  updated_time = stat.mtime
  updated_value = normalized["updated"]
  updated_value = format_timestamp(updated_time) if updated_value.nil? && updated_time > created_time + 120

  {
    "id" => generated_id(normalized["id"], type, source, created_time, used_ids),
    "title" => title,
    "aliases" => infer_aliases(normalized["aliases"], title, body, source),
    "type" => type,
    "status" => normalized["status"] || "inbox",
    "domain" => normalized["domain"] || infer_domain(title, body, source),
    "tags" => infer_tags(normalized["tags"], title, body, source),
    "context" => infer_context(normalized["context"], body),
    "created" => normalized["created"] || format_timestamp(created_time),
    "updated" => updated_value,
    "source" => source,
    "type_mbti" => normalized["type_mbti"],
    "origin" => normalized["origin"] || infer_origin(source, title, body),
    "linter-yaml-title-alias" => normalized["linter-yaml-title-alias"]
  }
end

def render_frontmatter(mapping)
  mapping.each_with_object(+"") do |(key, value), acc|
    acc << dump_value(key, value)
  end
end

def rebuild_content(frontmatter, body)
  normalized_body = body.sub(/\A\n+/, "")
  content = +"---\n"
  content << frontmatter
  content << "---\n"
  content << "\n" unless normalized_body.empty?
  content << normalized_body
  content << "\n" unless content.end_with?("\n")
  content
end

options = {
  target: DEFAULT_TARGET,
  template: DEFAULT_TEMPLATE,
  write: false,
  dry_run: true,
  verbose: false
}

OptionParser.new do |parser|
  parser.banner = "Usage: ruby apply_inbox_codex_template.rb [options]"

  parser.on("--target PATH", "Target inbox folder") do |path|
    options[:target] = Pathname.new(path)
  end

  parser.on("--template PATH", "Basic template path") do |path|
    options[:template] = Pathname.new(path)
  end

  parser.on("--write", "Write changes to disk") do
    options[:write] = true
    options[:dry_run] = false
  end

  parser.on("--dry-run", "Show what would change without writing") do
    options[:write] = false
    options[:dry_run] = true
  end

  parser.on("--verbose", "Print every inspected file") do
    options[:verbose] = true
  end
end.parse!

unless options[:template].file?
  warn "Template file was not found: #{options[:template]}"
  exit 1
end

unless options[:target].directory?
  warn "Target folder was not found: #{options[:target]}"
  exit 1
end

template_keys = template_key_order(options[:template])
files = Dir.glob(options[:target].join("**/*.md").to_s).sort

if files.empty?
  puts "No Markdown files found under #{options[:target]}"
  exit 0
end

changed = 0
used_ids = Set.new

files.each do |file_path|
  frontmatter, = split_frontmatter(File.read(file_path))
  existing = parse_frontmatter(frontmatter)
  existing_id = clean_string(existing["id"])
  used_ids << existing_id if existing_id
end

files.each do |file_path|
  path = Pathname.new(file_path)
  original = File.read(path)
  frontmatter, body = split_frontmatter(original)
  existing = parse_frontmatter(frontmatter)
  stat = path.stat

  inferred = inferred_values(path, existing, body, stat, used_ids)
  merged = build_frontmatter(template_keys, existing, inferred)
  rendered = render_frontmatter(merged)
  rebuilt = rebuild_content(rendered, body)
  file_changed = rebuilt != original

  changed += 1 if file_changed

  if options[:verbose] || options[:dry_run]
    state = file_changed ? "CHANGE" : "KEEP"
    relative = path.relative_path_from(options[:target])
    puts "#{state} #{relative}"
    puts "  id: #{merged['id']}"
    puts "  type: #{merged['type']}"
    puts "  status: #{merged['status']}"
    puts "  domain: #{merged['domain']}"
    puts "  source: #{merged['source'] || '(blank)'}"
    puts "  origin: #{merged['origin'] || '(blank)'}"
  end

  File.write(path, rebuilt) if options[:write] && file_changed
end

mode = options[:write] ? "updated" : "would update"
puts "#{files.size} file(s) inspected, #{changed} #{mode}."

#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"

OPTIONS = {
  write: false,
}

OptionParser.new do |parser|
  parser.banner = "Usage: scripts/sort-localizations.rb [--check|--write] [files...]"
  parser.on("--check", "Verify localization files are sorted and deduplicated") do
    OPTIONS[:write] = false
  end
  parser.on("--write", "Rewrite localization files in sorted, deduplicated order") do
    OPTIONS[:write] = true
  end
end.parse!

def default_localization_files
  Dir.glob("Preferences/Resources/*.lproj/*.strings").sort
end

def parse_strings_file(path)
  entries = {}
  duplicates = Hash.new { |hash, key| hash[key] = [] }

  File.readlines(path, chomp: true).each_with_index do |line, index|
    next if line.strip.empty?

    match = line.match(/\A\s*"((?:\\.|[^"\\])*)"\s*=\s*"((?:\\.|[^"\\])*)"\s*;\s*\z/)
    unless match
      raise "#{path}:#{index + 1}: unsupported .strings line format"
    end

    key = match[1]
    duplicates[key] << index + 1 if entries.key?(key)
    entries[key] = match[2]
  end

  [entries, duplicates]
end

def normalized_content(entries)
  entries
    .sort_by { |key, _value| key }
    .map { |key, value| "\"#{key}\" = \"#{value}\";\n" }
    .join
end

files = ARGV.empty? ? default_localization_files : ARGV
changed_files = []
deduplicated = {}

files.each do |path|
  entries, duplicates = parse_strings_file(path)
  content = normalized_content(entries)
  original = File.read(path)

  deduplicated[path] = duplicates unless duplicates.empty?

  if OPTIONS[:write]
    File.write(path, content) if content != original
  elsif content != original
    changed_files << path
  end
end

deduplicated.each do |path, duplicates|
  duplicates.each do |key, lines|
    warn "#{path}: deduplicated \"#{key}\" at lines #{lines.join(", ")}"
  end
end

if !OPTIONS[:write] && !changed_files.empty?
  changed_files.each { |path| warn "#{path}: not sorted or contains duplicate keys" }
  exit 1
end

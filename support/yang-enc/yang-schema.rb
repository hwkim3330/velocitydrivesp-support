#!/usr/bin/env ruby

# Copyright (c) 2021-2022 Microchip Technology Inc. and its subsidiaries.
# SPDX-License-Identifier: MIT

require_relative './yang-utils.rb'

def generate_yang_schema(yang_path, yangs, sids)
    threads = yangs.map do |yang|
        Thread.new do
            yin, stderr, status = Open3.capture3("pyang -W error --format yin --path #{yang_path} #{yang}")
            abort(stderr) if !status.success?
            yin
        end
    end

    modules = Yang::ModuleSet.new
    threads.each { |t| modules.add_module(t.value) }
    modules.schema
    sids.each { |s| modules.add_sid_file(s) }
    return modules.data
end

class PersistentYangSchema
    attr_reader :schema

    CFG_FILE   = "support/scripts/gen-cc-nodes.yaml"
    YANG_DIR   = "docs/sw_refs/yang"
    CACHE_FILE = ".velocitysp-yang-schema-cache"

    def initialize
        @schema = {}

        top = __dir__ # Script location
        2.times do    # Assume script is located two dirs above repository root
            top = File.dirname(top)
        end

        yangs, sids = read_yang_and_sid_files("#{top}/#{CFG_FILE}", "#{top}/#{YANG_DIR}")
        cache = read_cache("#{top}/#{CACHE_FILE}")
        if cache.nil? or cache[:yangs].to_s != yangs.to_s or cache[:sids].to_s != sids.to_s
            @schema = generate_yang_schema("#{top}/#{YANG_DIR}", yangs.keys, sids.keys)
            write_cache("#{top}/#{CACHE_FILE}", yangs, sids, @schema)
        else
            @schema = cache[:schema]
        end
    end

    def read_yang_and_sid_files(cfg_file, yang_dir)
        yangs = {}
        sids = {}
        YAML.load_file(cfg_file)['sid-files'].each do |s|
            sf = "#{yang_dir}/#{s}"
            abort("ERROR:L#{__LINE__}: SID file '#{sf}' not found!") if !File.exist?(sf)
            sids[sf] = File.mtime(sf)

            y = "#{s.split('@')[0]}.yang" # Transform sid file name to yang file name
            yf = "#{yang_dir}/#{y}"
            abort("ERROR:L#{__LINE__}: YANG file '#{yf}' not found!") if !File.exist?(yf)
            yangs[yf] = File.mtime(yf)
        end
        return yangs, sids
    end

    def read_cache(file)
        return nil if !File.exist?(file)
        return Marshal.load(File.read(file))
    end

    def write_cache(file, yangs, sids, schema)
        cache = { :yangs => yangs, :sids => sids, :schema => schema}
        File.write(file, Marshal.dump(cache))
    end
end

def yang_schema_get
    PersistentYangSchema.new().schema
end

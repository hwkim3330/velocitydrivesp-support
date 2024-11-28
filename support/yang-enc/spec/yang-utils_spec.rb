# Copyright (c) 2021-2022 Microchip Technology Inc. and its subsidiaries.
# SPDX-License-Identifier: MIT

require 'yang-utils'

include Yang

RSpec.describe ModuleSet do
    describe '#schema' do
        it 'expands groupings' do
            modules = ModuleSet.new.add_module(File.read(File.join(__dir__, 'tests', 'groupings.yin')))
            schema = modules.schema.find_module('groupings').schema
            leaf = schema.resolve_schema_path(['groupings:bar', 'baz'])
            expect(leaf.type.name).to eq 'int8'
        end

        it 'expands nested groupings' do
            modules = ModuleSet.new.add_module(File.read(File.join(__dir__, 'tests', 'groupings.yin')))
            schema = modules.schema.find_module('groupings').schema
            leaf = schema.resolve_schema_path(['groupings:bar', 'kage'])
            expect(leaf.type.name).to eq 'string'
        end
    end
end

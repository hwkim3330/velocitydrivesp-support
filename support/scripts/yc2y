#!/usr/bin/env ruby

# Copyright (c) 2021-2022 Microchip Technology Inc. and its subsidiaries.
# SPDX-License-Identifier: MIT

require_relative './yang-enc.rb'

$stdin.binmode
input_data = $stdin.read

puts cbor_seq2json(yang_schema_get, CBOR.decode_seq(input_data), 'yang').to_yaml


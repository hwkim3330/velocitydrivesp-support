#!/usr/bin/env ruby

# Copyright (c) 2021-2022 Microchip Technology Inc. and its subsidiaries.
# SPDX-License-Identifier: MIT

require_relative 'base.rb'

module Et
  module Handler
    class Uboot < Base
      PROMPTS = ["m => ", "ocelot # ", "luton # ", "jr2 # ",
                 "servalt # ", "=> "]

      def initialize dut, tracer = nil
        super("UBoot", dut, tracer)
        ll_handler_reg 0, self
        @seen_marker = false
        @seen_prompt = false
      end

      def timeout_work
        t = Time.now
        if t < @prompt_timeout
          # Injecting a periodic " \n", makes the prompt detection more robust.
          # Notice: the leading space is needed to avoid repeating a potential
          #         last command!
          l = " \n"
          ll_tx l
          #t(:debug, "Tick: #{l.inspect}")
          timeout_relative_set(1)
        end
      end

      def wait timeout, marker, prompt
        @buf_cmd = ""
        @buf_marker = ""
        @prompt_timeout = Time.now + timeout
        @seen_marker = marker
        @seen_prompt = prompt

        on()
        if timeout > 1
          timeout_relative_set(1)
        else
          timeout_relative_set(timeout)
        end

        while @timeout_self
          ll_poll()
        end

        off()
        return (@seen_marker and @seen_prompt)
      end

      def wait_for_boot timeout
        return wait(timeout, false, false)
      end

      def wait_for_prompt timeout
        return wait(timeout, true, false)
      end

      # Run a command which will return to UBoot again (and capture the output)
      def run cmd, timeout
        a = Time.now
        inject cmd
        wait_for_prompt timeout
        b = Time.now
        t(:info, "CMD-RETURN: #{cmd.inspect}, took #{b - a}s (#{@seen_marker} #{@seen_prompt})")

        res = @buf_cmd
        @buf_cmd = nil
        @buf_marker = nil

        if @seen_marker and @seen_prompt
          return res
        else
          return nil
        end
      end

      # Inject a command not returning to UBoot (like mj)
      def inject cmd
        cmd += "\n" if cmd[-1] != "\n"
        t(:info, "TX: #{cmd.inspect}")
        ll_tx "#{cmd}"
      end

      def on
        @on = true
      end

      def off
        @on = false
      end

      def rx type, s
        return nil if not @on

        @buf_marker += s
        @buf_cmd += s

        if not @seen_marker
          loop do
            o = @buf_marker.partition("\n")
            if o[1].size >= 1
              @buf_marker = o[2]
              case o[0]
              when /Hit any key to stop autoboot/,
                /Press SPACE to abort autoboot/,
                /Loading Environment from/
                t(:debug, "MARKER: #{o[0].inspect}")
                @seen_marker = true
                ll_tx " "

              when /ERROR:   Failed to load BL2 firmware./
                # Fail fast if stuck in TFA due to flash error
                @seen_marker = false
                t(:debug, "FAIL-FAST: #{o[0].inspect}")
                timeout_clear()

              end
            else
              break
            end
          end
        end

        if @seen_marker
          o = @buf_marker.rpartition("\n")
          @buf_marker = o[2]
          if PROMPTS.include? @buf_marker
            @seen_prompt = true
            #t(:debug, "PROMPT: #{@buf_marker.inspect}")
            timeout_clear()
          end
        end
      end
    end # Mup1 < Base
  end # Handler
end # Et


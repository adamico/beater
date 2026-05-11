module Audio
  module NativeBridge
    NATIVE_LIBRARY_NAME = "audio_stem_fx"
    NATIVE_MODULE_NAME = :AudioStemFx

    @attempted_load = false
    @warned = false
    @load_error = nil

    class << self
      def backend_mode
        load_extension_once!
        return :native if ready_for_streaming?

        warn_once
        :legacy
      end

      def ready_for_streaming?
        mod = extension_module
        return false unless mod
        return false unless mod.respond_to?(:stream_ready)
        return false unless mod.stream_ready

        mod.respond_to?(:configure_track) && mod.respond_to?(:next_chunk)
      end

      def load_stems(definitions)
        return unless ready_for_streaming?

        definitions.each do |track_name, definition|
          error = extension_module.load_stem(track_name.to_s, definition.input_path)
          if error.is_a?(String) && !error.empty?
            @load_error = "#{track_name}: #{error}"
            warn_once
            return false
          end
        end

        true
      rescue StandardError => e
        @load_error = e.message
        warn_once
        false
      end

      def push_track_params(track_name:, cutoff_hz:, resonance:, gain:, bypass_mix:)
        return unless ready_for_streaming?

        extension_module.configure_track(
          track_name.to_s,
          cutoff_hz ? cutoff_hz.to_f : -1.0,
          resonance ? resonance.to_f : -1.0,
          gain.to_f,
          bypass_mix.to_f
        )
      rescue StandardError => e
        @load_error = e.message
        warn_once
      end

      def next_chunk(track_name:, input_path:, offset_frames:, frame_count:)
        return [] unless ready_for_streaming?

        extension_module.next_chunk(track_name.to_s, input_path.to_s, offset_frames.to_i, frame_count.to_i)
      rescue StandardError => e
        @load_error = e.message
        warn_once
        []
      end

      def reset_runtime_state!
        if ready_for_streaming? && extension_module.respond_to?(:reset_all)
          extension_module.reset_all
        end

        @warned = false
      rescue StandardError => e
        @load_error = e.message
      end

      def status_text
        mode = backend_mode
        return "audio backend: native" if mode == :native

        detail = @load_error.to_s.empty? ? "native extension unavailable" : @load_error
        "audio backend: legacy (#{detail})"
      end

      private

      def extension_module
        return nil unless Object.const_defined?(:FFI)
        return nil unless FFI.const_defined?(NATIVE_MODULE_NAME)

        FFI.const_get(NATIVE_MODULE_NAME)
      end

      def load_extension_once!
        return if @attempted_load

        @attempted_load = true

        unless runtime_available?
          @load_error = "ffi runtime unavailable"
          puts "[Audio::NativeBridge] FFI runtime check failed: #{@load_error}"
          return
        end

        DR.ffi_misc.gtk_dlopen(NATIVE_LIBRARY_NAME)
        @load_error = nil
      rescue StandardError => e
        @load_error = e.message
        puts "[Audio::NativeBridge] Failed to load native extension: #{e.message}"
      end

      def runtime_available?
        return false unless Object.const_defined?(:DR)

        begin
          misc = DR.ffi_misc
          !misc.nil? && misc.respond_to?(:gtk_dlopen)
        rescue StandardError
          false
        end
      end

      def warn_once
        return if @warned

        @warned = true
        puts "[Audio::NativeBridge] Falling back to legacy audio backend: #{@load_error || 'unknown reason'}"
      end
    end
  end
end

#include <dragonruby.h>
#include <mruby.h>
#include <mruby/array.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static drb_api_t *drb_api;

/* ============================================================================
   WAV Header Parsing
   ============================================================================ */

typedef struct {
  uint16_t format;
  uint16_t channels;
  uint32_t sample_rate;
  uint32_t byte_rate;
  uint16_t block_align;
  uint16_t bits_per_sample;
} WavFmt;

typedef struct {
  float *samples;
  uint32_t sample_count;
  WavFmt fmt;
} WavBuffer;

/* ============================================================================
   Biquad Filter State + DJ Morph
   ============================================================================ */

typedef struct {
  float z1_lp, z2_lp;  /* Lowpass delay line */
  float z1_hp, z2_hp;  /* Highpass delay line */
  float b0_lp, b1_lp, b2_lp, a1_lp, a2_lp;  /* LP coeffs */
  float b0_hp, b1_hp, b2_hp, a1_hp, a2_hp;  /* HP coeffs */
} BiquadState;

/* ============================================================================
   Per-Track DSP State
   ============================================================================ */

typedef struct {
  WavBuffer wav;
  uint32_t offset_frames;
  BiquadState biquad;
  
  float cutoff_hz;
  float resonance;
  float gain;
  float bypass_mix;
  
  int track_type;  /* 0=bypass, 1=lowpass, 2=dj_morph */
} TrackState;

typedef struct {
  TrackState drums;
  TrackState bass;
  TrackState lead;
  TrackState chords;
  int initialized;
} AudioState;

static AudioState g_state = {0};

/* ============================================================================
   WAV File Loading
   ============================================================================ */

static int read_wav_file(const char *path, WavBuffer *out) {
  FILE *f = fopen(path, "rb");
  if (!f) return -1;

  uint8_t header[12];
  if (fread(header, 1, 12, f) != 12) { fclose(f); return -1; }
  
  if (memcmp(header, "RIFF", 4) != 0 || memcmp(header + 8, "WAVE", 4) != 0) {
    fclose(f);
    return -1;
  }

  WavFmt fmt = {0};
  uint32_t data_size = 0;
  int found_fmt = 0, found_data = 0;

  while (!found_data) {
    uint8_t chunk_header[8];
    if (fread(chunk_header, 1, 8, f) != 8) { fclose(f); return -1; }

    char chunk_id[4];
    memcpy(chunk_id, chunk_header, 4);
    uint32_t chunk_size = *(uint32_t *)(chunk_header + 4);

    if (memcmp(chunk_id, "fmt ", 4) == 0) {
      if (chunk_size < 16) { fclose(f); return -1; }
      uint8_t fmt_data[16];
      if (fread(fmt_data, 1, 16, f) != 16) { fclose(f); return -1; }

      fmt.format = *(uint16_t *)(fmt_data + 0);
      fmt.channels = *(uint16_t *)(fmt_data + 2);
      fmt.sample_rate = *(uint32_t *)(fmt_data + 4);
      fmt.byte_rate = *(uint32_t *)(fmt_data + 8);
      fmt.block_align = *(uint16_t *)(fmt_data + 12);
      fmt.bits_per_sample = *(uint16_t *)(fmt_data + 14);

      if (chunk_size > 16) fseek(f, chunk_size - 16, SEEK_CUR);
      found_fmt = 1;
    } else if (memcmp(chunk_id, "data", 4) == 0) {
      data_size = chunk_size;
      found_data = 1;
    } else {
      fseek(f, chunk_size, SEEK_CUR);
    }
  }

  if (!found_fmt || fmt.channels != 2 || fmt.sample_rate != 44100 ||
      (fmt.format != 1 && fmt.format != 3) ||
      (fmt.format == 1 && fmt.bits_per_sample != 16) ||
      (fmt.format == 3 && fmt.bits_per_sample != 32)) {
    fclose(f);
    return -1;
  }

  uint32_t sample_count = data_size / fmt.block_align;
  float *samples = (float *)malloc(sample_count * 2 * sizeof(float));
  if (!samples) { fclose(f); return -1; }

  if (fmt.format == 1) {
    int16_t *pcm16 = (int16_t *)malloc(data_size);
    if (!pcm16) { free(samples); fclose(f); return -1; }
    if (fread(pcm16, 1, data_size, f) != data_size) {
      free(pcm16); free(samples); fclose(f); return -1;
    }
    for (uint32_t i = 0; i < sample_count * 2; i++) {
      samples[i] = pcm16[i] / 32768.0f;
    }
    free(pcm16);
  } else {
    float *pcm32 = (float *)malloc(data_size);
    if (!pcm32) { free(samples); fclose(f); return -1; }
    if (fread(pcm32, 1, data_size, f) != data_size) {
      free(pcm32); free(samples); fclose(f); return -1;
    }
    memcpy(samples, pcm32, data_size);
    free(pcm32);
  }

  fclose(f);

  out->samples = samples;
  out->sample_count = sample_count;
  out->fmt = fmt;
  return 0;
}

/* ============================================================================
   Biquad Coefficient Calculation (RBJ Audio EQ Cookbook)
   ============================================================================ */

static void biquad_lowpass(float cutoff_hz, float Q, BiquadState *state) {
  float w0 = 2.0f * 3.14159265f * cutoff_hz / 44100.0f;
  float sin_w0 = sinf(w0);
  float cos_w0 = cosf(w0);
  float alpha = sin_w0 / (2.0f * Q);

  float b0 = (1.0f - cos_w0) / 2.0f;
  float b1 = 1.0f - cos_w0;
  float b2 = (1.0f - cos_w0) / 2.0f;
  float a0 = 1.0f + alpha;
  float a1 = -2.0f * cos_w0;
  float a2 = 1.0f - alpha;

  state->b0_lp = b0 / a0;
  state->b1_lp = b1 / a0;
  state->b2_lp = b2 / a0;
  state->a1_lp = a1 / a0;
  state->a2_lp = a2 / a0;
}

static void biquad_highpass(float cutoff_hz, float Q, BiquadState *state) {
  float w0 = 2.0f * 3.14159265f * cutoff_hz / 44100.0f;
  float sin_w0 = sinf(w0);
  float cos_w0 = cosf(w0);
  float alpha = sin_w0 / (2.0f * Q);

  float b0 = (1.0f + cos_w0) / 2.0f;
  float b1 = -(1.0f + cos_w0);
  float b2 = (1.0f + cos_w0) / 2.0f;
  float a0 = 1.0f + alpha;
  float a1 = -2.0f * cos_w0;
  float a2 = 1.0f - alpha;

  state->b0_hp = b0 / a0;
  state->b1_hp = b1 / a0;
  state->b2_hp = b2 / a0;
  state->a1_hp = a1 / a0;
  state->a2_hp = a2 / a0;
}

/* ============================================================================
   Biquad Filter Application
   ============================================================================ */

static inline float biquad_process_lp(BiquadState *state, float x) {
  float y = state->b0_lp * x + state->b1_lp * 0 + state->b2_lp * 0 
           - state->a1_lp * state->z1_lp - state->a2_lp * state->z2_lp;
  state->z2_lp = state->z1_lp;
  state->z1_lp = y;
  return y;
}

static inline float biquad_process_hp(BiquadState *state, float x) {
  float y = state->b0_hp * x + state->b1_hp * 0 + state->b2_hp * 0 
           - state->a1_hp * state->z1_hp - state->a2_hp * state->z2_hp;
  state->z2_hp = state->z1_hp;
  state->z1_hp = y;
  return y;
}

/* ============================================================================
   Soft Limiter (tanh-based)
   ============================================================================ */

static inline float soft_limit(float x, float drive) {
  float driven = drive * x;
  return tanhf(driven) / tanhf(drive);
}

/* ============================================================================
   Chunk Generator
   ============================================================================ */

static void track_process_chunk(TrackState *track, uint32_t frame_count, float *out_l, float *out_r) {
  if (!track->wav.samples) {
    memset(out_l, 0, frame_count * sizeof(float));
    memset(out_r, 0, frame_count * sizeof(float));
    return;
  }

  for (uint32_t i = 0; i < frame_count; i++) {
    uint32_t sample_idx = (track->offset_frames + i) % track->wav.sample_count;
    float l = track->wav.samples[sample_idx * 2];
    float r = track->wav.samples[sample_idx * 2 + 1];

    if (track->track_type == 1) {
      l = biquad_process_lp(&track->biquad, l);
      r = biquad_process_lp(&track->biquad, r);
    } else if (track->track_type == 2) {
      float lp_l = biquad_process_lp(&track->biquad, l);
      float lp_r = biquad_process_lp(&track->biquad, r);
      float hp_l = biquad_process_hp(&track->biquad, l);
      float hp_r = biquad_process_hp(&track->biquad, r);
      float morph = track->bypass_mix;
      l = hp_l * (1.0f - morph) + lp_l * morph;
      r = hp_r * (1.0f - morph) + lp_r * morph;
    }

    float wet_l = l * track->gain;
    float wet_r = r * track->gain;
    
    out_l[i] = wet_l;
    out_r[i] = wet_r;
  }

  track->offset_frames = (track->offset_frames + frame_count) % track->wav.sample_count;
}

static mrb_value ffi_stream_ready(mrb_state *mrb, mrb_value self) {
  return g_state.initialized ? mrb_true_value() : mrb_false_value();
}

static mrb_value ffi_load_stem(mrb_state *mrb, mrb_value self) {
  const char *track_name = NULL;
  const char *file_path = NULL;
  drb_api->mrb_get_args(mrb, "zz", &track_name, &file_path);

  TrackState *track = NULL;
  int track_type = 0;

  if (strcmp(track_name, "drums") == 0) {
    track = &g_state.drums;
    track_type = 2;
  } else if (strcmp(track_name, "bass") == 0) {
    track = &g_state.bass;
    track_type = 1;
  } else if (strcmp(track_name, "lead") == 0) {
    track = &g_state.lead;
    track_type = 2;
  } else if (strcmp(track_name, "chords") == 0) {
    track = &g_state.chords;
    track_type = 1;
  } else {
    return drb_api->mrb_str_new_cstr(mrb, "unknown track name");
  }

  if (read_wav_file(file_path, &track->wav) != 0) {
    return drb_api->mrb_str_new_cstr(mrb, "failed to load or invalid WAV file");
  }

  track->track_type = track_type;
  track->offset_frames = 0;
  track->cutoff_hz = 1000.0f;
  track->resonance = 1.0f;
  track->gain = 0.5f;
  track->bypass_mix = 0.0f;
  memset(&track->biquad, 0, sizeof(BiquadState));

  if (track_type == 1) {
    biquad_lowpass(track->cutoff_hz, track->resonance, &track->biquad);
  } else if (track_type == 2) {
    biquad_lowpass(track->cutoff_hz, track->resonance, &track->biquad);
    biquad_highpass(track->cutoff_hz, track->resonance, &track->biquad);
  }

  return mrb_nil_value();
}

static mrb_value ffi_configure_track(mrb_state *mrb, mrb_value self) {
  const char *track_name = NULL;
  mrb_float cutoff_hz = 0;
  mrb_float resonance = 0;
  mrb_float gain = 0;
  mrb_float bypass_mix = 0;
  drb_api->mrb_get_args(mrb, "zffff", &track_name, &cutoff_hz, &resonance, &gain, &bypass_mix);

  TrackState *track = NULL;
  if (strcmp(track_name, "drums") == 0) {
    track = &g_state.drums;
  } else if (strcmp(track_name, "bass") == 0) {
    track = &g_state.bass;
  } else if (strcmp(track_name, "lead") == 0) {
    track = &g_state.lead;
  } else if (strcmp(track_name, "chords") == 0) {
    track = &g_state.chords;
  } else {
    return mrb_nil_value();
  }

  if (cutoff_hz > 0) track->cutoff_hz = cutoff_hz;
  if (resonance > 0) track->resonance = resonance;
  if (gain >= 0) track->gain = gain;
  if (bypass_mix >= 0) track->bypass_mix = bypass_mix;

  if (track->track_type == 1) {
    biquad_lowpass(track->cutoff_hz, track->resonance, &track->biquad);
  } else if (track->track_type == 2) {
    biquad_lowpass(track->cutoff_hz, track->resonance, &track->biquad);
    biquad_highpass(track->cutoff_hz, track->resonance, &track->biquad);
  }

  return mrb_nil_value();
}

static mrb_value ffi_next_chunk(mrb_state *mrb, mrb_value self) {
  const char *track_name = NULL;
  const char *input_path = NULL;
  mrb_int offset_frames = 0;
  mrb_int frame_count = 0;
  drb_api->mrb_get_args(mrb, "zzii", &track_name, &input_path, &offset_frames, &frame_count);

  TrackState *track = NULL;
  if (strcmp(track_name, "drums") == 0) {
    track = &g_state.drums;
  } else if (strcmp(track_name, "bass") == 0) {
    track = &g_state.bass;
  } else if (strcmp(track_name, "lead") == 0) {
    track = &g_state.lead;
  } else if (strcmp(track_name, "chords") == 0) {
    track = &g_state.chords;
  } else {
    return drb_api->mrb_ary_new(mrb);
  }

  float *out_l = (float *)malloc(frame_count * sizeof(float));
  float *out_r = (float *)malloc(frame_count * sizeof(float));
  if (!out_l || !out_r) {
    free(out_l);
    free(out_r);
    return drb_api->mrb_ary_new(mrb);
  }

  track_process_chunk(track, frame_count, out_l, out_r);

  mrb_value ary = drb_api->mrb_ary_new(mrb);
  for (int i = 0; i < frame_count; i++) {
    float limited_l = soft_limit(out_l[i], 1.5f);
    float limited_r = soft_limit(out_r[i], 1.5f);
    drb_api->mrb_ary_push(mrb, ary, drb_api->mrb_float_value(mrb, limited_l));
    drb_api->mrb_ary_push(mrb, ary, drb_api->mrb_float_value(mrb, limited_r));
  }

  free(out_l);
  free(out_r);
  return ary;
}

static mrb_value ffi_reset_all(mrb_state *mrb, mrb_value self) {
  g_state.drums.offset_frames = 0;
  g_state.bass.offset_frames = 0;
  g_state.lead.offset_frames = 0;
  g_state.chords.offset_frames = 0;

  memset(&g_state.drums.biquad, 0, sizeof(BiquadState));
  memset(&g_state.bass.biquad, 0, sizeof(BiquadState));
  memset(&g_state.lead.biquad, 0, sizeof(BiquadState));
  memset(&g_state.chords.biquad, 0, sizeof(BiquadState));

  return mrb_nil_value();
}

DRB_FFI_EXPORT
void drb_register_c_extensions_with_api(mrb_state *mrb, struct drb_api_t *api) {
  drb_api = api;
  g_state.initialized = 1;

  struct RClass *FFI = drb_api->mrb_module_get(mrb, "FFI");
  struct RClass *module = drb_api->mrb_define_module_under(mrb, FFI, "AudioStemFx");

  drb_api->mrb_define_module_function(mrb, module, "stream_ready", ffi_stream_ready, MRB_ARGS_NONE());
  drb_api->mrb_define_module_function(mrb, module, "load_stem", ffi_load_stem, MRB_ARGS_ANY());
  drb_api->mrb_define_module_function(mrb, module, "configure_track", ffi_configure_track, MRB_ARGS_ANY());
  drb_api->mrb_define_module_function(mrb, module, "next_chunk", ffi_next_chunk, MRB_ARGS_ANY());
  drb_api->mrb_define_module_function(mrb, module, "reset_all", ffi_reset_all, MRB_ARGS_NONE());
}

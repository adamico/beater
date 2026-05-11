#include <dragonruby.h>
#include <mruby.h>
#include <mruby/array.h>

static drb_api_t *drb_api;

static mrb_value ffi_stream_ready(mrb_state *mrb, mrb_value self) {
  return mrb_false_value();
}

static mrb_value ffi_load_stem(mrb_state *mrb, mrb_value self) {
  mrb_value *args = 0;
  mrb_int argc = 0;
  drb_api->mrb_get_args(mrb, "*", &args, &argc);
  return mrb_true_value();
}

static mrb_value ffi_configure_track(mrb_state *mrb, mrb_value self) {
  mrb_value *args = 0;
  mrb_int argc = 0;
  drb_api->mrb_get_args(mrb, "*", &args, &argc);
  return mrb_nil_value();
}

static mrb_value ffi_next_chunk(mrb_state *mrb, mrb_value self) {
  mrb_value *args = 0;
  mrb_int argc = 0;
  drb_api->mrb_get_args(mrb, "*", &args, &argc);
  return drb_api->mrb_ary_new(mrb);
}

static mrb_value ffi_reset_all(mrb_state *mrb, mrb_value self) {
  return mrb_nil_value();
}

DRB_FFI_EXPORT
void drb_register_c_extensions_with_api(mrb_state *mrb, struct drb_api_t *api) {
  drb_api = api;

  struct RClass *FFI = drb_api->mrb_module_get(mrb, "FFI");
  struct RClass *module = drb_api->mrb_define_module_under(mrb, FFI, "AudioStemFx");

  drb_api->mrb_define_module_function(mrb, module, "stream_ready", ffi_stream_ready, MRB_ARGS_NONE());
  drb_api->mrb_define_module_function(mrb, module, "load_stem", ffi_load_stem, MRB_ARGS_ANY());
  drb_api->mrb_define_module_function(mrb, module, "configure_track", ffi_configure_track, MRB_ARGS_ANY());
  drb_api->mrb_define_module_function(mrb, module, "next_chunk", ffi_next_chunk, MRB_ARGS_ANY());
  drb_api->mrb_define_module_function(mrb, module, "reset_all", ffi_reset_all, MRB_ARGS_NONE());
}

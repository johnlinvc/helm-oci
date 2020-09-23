#include <stdlib.h>
#include <stdio.h>

#include <mruby.h>
#include <mruby/irep.h>
#include <mruby/proc.h>
#include <mruby/array.h>
#include <mruby/data.h>

#include "../tmp/helm_oci.c"

int
main(int argc, const char ** argv)
{
  mrb_state *mrb = mrb_open();
  if (!mrb) { /* handle error */ }

  mrb_value ARGV;
  ARGV = mrb_ary_new_capa(mrb, argc);
  int i;
  for (i = 0; i < argc; i++) {
    mrb_ary_push(mrb, ARGV, mrb_str_new(mrb, argv[i], strlen(argv[i])));
  }
  mrb_define_global_const(mrb, "ARGV", ARGV);

  mrb_load_irep(mrb, helm_oci);
  mrb_close(mrb);
  return 0;
}

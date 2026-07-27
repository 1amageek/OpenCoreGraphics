#ifndef C_OPEN_CORE_GRAPHICS_SUPPORT_H
#define C_OPEN_CORE_GRAPHICS_SUPPORT_H

#include <stddef.h>
#include <stdint.h>

double ocg_sin(double value);
double ocg_cos(double value);
double ocg_tan(double value);
double ocg_atan2(double y, double x);
double ocg_sqrt(double value);
double ocg_hypot(double x, double y);
double ocg_pow(double base, double exponent);
double ocg_exp(double value);
double ocg_log(double value);
double ocg_log2(double value);
double ocg_log10(double value);
double ocg_acos(double value);
double ocg_floor(double value);
double ocg_ceil(double value);

int32_t ocg_read_file(
    const char *path,
    uint8_t **output_bytes,
    size_t *output_count
);
int32_t ocg_write_file(
    const char *path,
    const uint8_t *bytes,
    size_t count
);
void ocg_release_bytes(void *bytes);

#endif

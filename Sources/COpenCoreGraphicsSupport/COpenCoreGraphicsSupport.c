#include "COpenCoreGraphicsSupport.h"

#include <errno.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

double ocg_sin(double value) { return sin(value); }
double ocg_cos(double value) { return cos(value); }
double ocg_tan(double value) { return tan(value); }
double ocg_atan2(double y, double x) { return atan2(y, x); }
double ocg_sqrt(double value) { return sqrt(value); }
double ocg_hypot(double x, double y) { return hypot(x, y); }
double ocg_pow(double base, double exponent) { return pow(base, exponent); }
double ocg_exp(double value) { return exp(value); }
double ocg_log(double value) { return log(value); }
double ocg_log2(double value) { return log2(value); }
double ocg_log10(double value) { return log10(value); }
double ocg_acos(double value) { return acos(value); }
double ocg_floor(double value) { return floor(value); }
double ocg_ceil(double value) { return ceil(value); }

int32_t ocg_read_file(
    const char *path,
    uint8_t **output_bytes,
    size_t *output_count
) {
    if (path == NULL || output_bytes == NULL || output_count == NULL) {
        return EINVAL;
    }

    *output_bytes = NULL;
    *output_count = 0;

    FILE *file = fopen(path, "rb");
    if (file == NULL) {
        return errno == 0 ? EIO : errno;
    }

    if (fseek(file, 0, SEEK_END) != 0) {
        int32_t error_code = errno == 0 ? EIO : errno;
        fclose(file);
        return error_code;
    }

    long file_length = ftell(file);
    if (file_length < 0) {
        int32_t error_code = errno == 0 ? EIO : errno;
        fclose(file);
        return error_code;
    }

    if (fseek(file, 0, SEEK_SET) != 0) {
        int32_t error_code = errno == 0 ? EIO : errno;
        fclose(file);
        return error_code;
    }

    if (file_length == 0) {
        fclose(file);
        return 0;
    }

    size_t byte_count = (size_t)file_length;
    uint8_t *bytes = malloc(byte_count);
    if (bytes == NULL) {
        fclose(file);
        return ENOMEM;
    }

    size_t read_count = fread(bytes, 1, byte_count, file);
    if (read_count != byte_count) {
        int32_t error_code = ferror(file) && errno != 0 ? errno : EIO;
        free(bytes);
        fclose(file);
        return error_code;
    }

    if (fclose(file) != 0) {
        int32_t error_code = errno == 0 ? EIO : errno;
        free(bytes);
        return error_code;
    }

    *output_bytes = bytes;
    *output_count = byte_count;
    return 0;
}

int32_t ocg_write_file(
    const char *path,
    const uint8_t *bytes,
    size_t count
) {
    if (path == NULL || (bytes == NULL && count != 0)) {
        return EINVAL;
    }

    FILE *file = fopen(path, "wb");
    if (file == NULL) {
        return errno == 0 ? EIO : errno;
    }

    if (count != 0 && fwrite(bytes, 1, count, file) != count) {
        int32_t error_code = errno == 0 ? EIO : errno;
        fclose(file);
        return error_code;
    }

    if (fclose(file) != 0) {
        return errno == 0 ? EIO : errno;
    }

    return 0;
}

void ocg_release_bytes(void *bytes) {
    free(bytes);
}

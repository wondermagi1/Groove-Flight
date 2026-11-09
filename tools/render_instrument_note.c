#define TSF_IMPLEMENTATION
#include "tsf.h"
#include <stdio.h>
#include <stdlib.h>

/* Offline asset builder only; no synthesizer is required at game runtime. */
int main(int argc, char **argv) {
    if (argc < 8 || argc > 10) return 2;
    tsf *font = tsf_load_filename(argv[1]);
    if (!font) return 3;
    int preset = tsf_get_presetindex(font, atoi(argv[2]), atoi(argv[3]));
    if (preset < 0) { tsf_close(font); return 4; }
    /* Optional sampled short-bow articulation: amplitude envelope only.
       Sample pitch, sample playback rate and the recorded waveform stay intact. */
    if (argc == 10) {
        float attack = (float)atof(argv[9]);
        if (attack <= 0.f || attack > .1f) { tsf_close(font); return 8; }
        for (int i = 0; i < font->presets[preset].regionNum; ++i) {
            struct tsf_region *region = &font->presets[preset].regions[i];
            if (region->ampenv.attack > attack) region->ampenv.attack = attack;
            if (region->ampenv.delay > .001f) region->ampenv.delay = .001f;
        }
    }
    int note = atoi(argv[4]), hold = (int)(atof(argv[5]) * 22050), tail = (int)(atof(argv[6]) * 22050);
    float *pcm = (float *)calloc(hold + tail, sizeof(float));
    if (!pcm) { tsf_close(font); return 5; }
    tsf_set_output(font, TSF_MONO, 22050, 0);
    float velocity = argc >= 9 ? (float)atof(argv[8]) : .8f;
    if (velocity <= 0.f || velocity > 1.f) { free(pcm); tsf_close(font); return 7; }
    tsf_note_on(font, preset, note, velocity);
    tsf_render_float(font, pcm, hold, 0);
    tsf_note_off(font, preset, note);
    tsf_render_float(font, pcm + hold, tail, 0);
    FILE *out = fopen(argv[7], "wb");
    if (!out) { free(pcm); tsf_close(font); return 6; }
    fwrite(pcm, sizeof(float), hold + tail, out); fclose(out);
    printf("%s\n", tsf_get_presetname(font, preset));
    free(pcm); tsf_close(font); return 0;
}

// AAC-ELD decoder. libavcodec struct layouts change between versions, so Rust does not touch them directly.
#include <libavcodec/avcodec.h>
#include <string.h>

typedef struct {
    AVCodecContext *ctx;
    AVPacket *pkt;
    AVFrame *frame;
} Eld;

void eld_free(Eld *e) {
    if (!e)
        return;
    avcodec_free_context(&e->ctx);
    av_packet_free(&e->pkt);
    av_frame_free(&e->frame);
    av_free(e);
}

Eld *eld_new(const unsigned char *asc, int asc_len, int rate) {
    const AVCodec *c = avcodec_find_decoder(AV_CODEC_ID_AAC);
    Eld *e = av_mallocz(sizeof(Eld));
    if (!c || !e)
        return NULL;
    e->ctx = avcodec_alloc_context3(c);
    e->pkt = av_packet_alloc();
    e->frame = av_frame_alloc();
    if (!e->ctx || !e->pkt || !e->frame)
        goto fail;
    e->ctx->extradata = av_mallocz(asc_len + AV_INPUT_BUFFER_PADDING_SIZE);
    if (!e->ctx->extradata)
        goto fail;
    memcpy(e->ctx->extradata, asc, asc_len);
    e->ctx->extradata_size = asc_len;
    e->ctx->sample_rate = rate;
    av_channel_layout_default(&e->ctx->ch_layout, 1);
    if (avcodec_open2(e->ctx, c, NULL) < 0)
        goto fail;
    return e;
fail:
    eld_free(e);
    return NULL;
}

// Decodes one frame into out as mono float; returns the sample count, or -1 on error.
int eld_decode(Eld *e, const unsigned char *au, int len, float *out, int max) {
    if (av_new_packet(e->pkt, len) < 0)
        return -1;
    memcpy(e->pkt->data, au, len);
    int r = avcodec_send_packet(e->ctx, e->pkt);
    av_packet_unref(e->pkt);
    if (r < 0)
        return -1;
    int n = 0;
    while (avcodec_receive_frame(e->ctx, e->frame) == 0) {
        int ns = e->frame->nb_samples;
        if (ns > max - n)
            ns = max - n;
        if (e->frame->format == AV_SAMPLE_FMT_FLTP || e->frame->format == AV_SAMPLE_FMT_FLT)
            memcpy(out + n, e->frame->data[0], ns * sizeof(float));
        else
            ns = 0;
        n += ns;
        av_frame_unref(e->frame);
    }
    return n;
}

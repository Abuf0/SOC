#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <windows.h>
#include <wincrypt.h>
#include "moc_engine.h"
#define mult_32x32_keep32_R(a,x,y) \
    a = (q31_t)(((q63_t)x*y+0x80000000LL) >> 32)

#define multAcc_32x32_keep32_R(a,x,y) \
    a = (q31_t)(((((q63_t)a) << 32) + ((q63_t)x*y) + 0x80000000LL) >> 32)

#define multSub_32x32_keep32_R(a,x,y) \
a = (q31_t)(((((q63_t)a) << 32) - ((q63_t)x*y) + 0x80000000LL) >> 32)

/**
 * @brief  Core function for the Q31 CIFFT butterfly process.
 * @param[in, out] *pSrc            points to the in-place buffer of Q31 data type.
 * @param[in]      fftLen           length of the FFT.
 * @param[in]      *pCoef           points to twiddle coefficient buffer.
 * @param[in]      twidCoefModifier twiddle coefficient modifier that supports different size FFTs with the same twiddle factor table.
 * @return none.
 */


/*
* Radix-4 IFFT algorithm used is :
*
* CIFFT uses same twiddle coefficients as CFFT Function
*  x[k] = x[n] + (j)k * x[n + fftLen/4] + (-1)k * x[n+fftLen/2] + (-j)k * x[n+3*fftLen/4]
*
*
* IFFT is implemented with following changes in equations from FFT
*
* Input real and imaginary data:
* x(n) = xa + j * ya
* x(n+N/4 ) = xb + j * yb
* x(n+N/2 ) = xc + j * yc
* x(n+3N 4) = xd + j * yd
*
*
* Output real and imaginary data:
* x(4r) = xa'+ j * ya'
* x(4r+1) = xb'+ j * yb'
* x(4r+2) = xc'+ j * yc'
* x(4r+3) = xd'+ j * yd'
*
*
* Twiddle factors for radix-4 IFFT:
* Wn = co1 + j * (si1)
* W2n = co2 + j * (si2)
* W3n = co3 + j * (si3)

* The real and imaginary output values for the radix-4 butterfly are
* xa' = xa + xb + xc + xd
* ya' = ya + yb + yc + yd
* xb' = (xa-yb-xc+yd)* co1 - (ya+xb-yc-xd)* (si1)
* yb' = (ya+xb-yc-xd)* co1 + (xa-yb-xc+yd)* (si1)
* xc' = (xa-xb+xc-xd)* co2 - (ya-yb+yc-yd)* (si2)
* yc' = (ya-yb+yc-yd)* co2 + (xa-xb+xc-xd)* (si2)
* xd' = (xa+yb-xc-yd)* co3 - (ya-xb-yc+xd)* (si3)
* yd' = (ya-xb-yc+xd)* co3 + (xa+yb-xc-yd)* (si3)
*
*/

static void arm_radix4_butterfly_inverse_q31(
    q31_t * pSrc,
    uint32_t fftLen,
    const q31_t * pCoef,
    uint32_t twidCoefModifier
)
{
    uint32_t n1, n2, ia1, ia2, ia3, i0, i1, i2, i3, j, k;
    q31_t t1, t2, r1, r2, s1, s2, co1, co2, co3, si1, si2, si3;
    q31_t xa, xb, xc, xd;
    q31_t ya, yb, yc, yd;
    q31_t xa_out, xb_out, xc_out, xd_out;
    q31_t ya_out, yb_out, yc_out, yd_out;

    q31_t *ptr1;

    /* input is be 1.31(q31) format for all FFT sizes */
    /* Total process is divided into three stages */
    /* process first stage, middle stages, & last stage */

    /* Start of first stage process */

    /* Initializations for the first stage */
    n2 = fftLen;
    n1 = n2;
    /* n2 = fftLen/4 */
    n2 >>= 2u;
    i0 = 0u;
    ia1 = 0u;

    j = n2;

    do
    {

      /* input is in 1.31(q31) format and provide 4 guard bits for the input */

      /*  index calculation for the input as, */
      /*  pSrc[i0 + 0], pSrc[i0 + fftLen/4], pSrc[i0 + fftLen/2u], pSrc[i0 + 3fftLen/4] */
      i1 = i0 + n2;
      i2 = i1 + n2;
      i3 = i2 + n2;

      /*  Butterfly implementation */
      /* xa + xc */
      r1 = (pSrc[2u * i0] >> 4u) + (pSrc[2u * i2] >> 4u);
      /* xa - xc */
      r2 = (pSrc[2u * i0] >> 4u) - (pSrc[2u * i2] >> 4u);

      /* xb + xd */
      t1 = (pSrc[2u * i1] >> 4u) + (pSrc[2u * i3] >> 4u);

      /* ya + yc */
      s1 = (pSrc[(2u * i0) + 1u] >> 4u) + (pSrc[(2u * i2) + 1u] >> 4u);
      /* ya - yc */
      s2 = (pSrc[(2u * i0) + 1u] >> 4u) - (pSrc[(2u * i2) + 1u] >> 4u);

      /* xa' = xa + xb + xc + xd */
      pSrc[2u * i0] = (r1 + t1);
      /* (xa + xc) - (xb + xd) */
      r1 = r1 - t1;
      /* yb + yd */
      t2 = (pSrc[(2u * i1) + 1u] >> 4u) + (pSrc[(2u * i3) + 1u] >> 4u);
      /* ya' = ya + yb + yc + yd */
      pSrc[(2u * i0) + 1u] = (s1 + t2);

      /* (ya + yc) - (yb + yd) */
      s1 = s1 - t2;

      /* yb - yd */
      t1 = (pSrc[(2u * i1) + 1u] >> 4u) - (pSrc[(2u * i3) + 1u] >> 4u);
      /* xb - xd */
      t2 = (pSrc[2u * i1] >> 4u) - (pSrc[2u * i3] >> 4u);

      /*  index calculation for the coefficients */
      ia2 = 2u * ia1;
      co2 = pCoef[ia2 * 2u];
      si2 = pCoef[(ia2 * 2u) + 1u];

      /* xc' = (xa-xb+xc-xd)co2 - (ya-yb+yc-yd)(si2) */
      pSrc[2u * i1] = (((int32_t) (((q63_t) r1 * co2) >> 32)) -
                       ((int32_t) (((q63_t) s1 * si2) >> 32))) << 1u;

      /* yc' = (ya-yb+yc-yd)co2 + (xa-xb+xc-xd)(si2) */
      pSrc[2u * i1 + 1u] = (((int32_t) (((q63_t) s1 * co2) >> 32)) +
                            ((int32_t) (((q63_t) r1 * si2) >> 32))) << 1u;

      /* (xa - xc) - (yb - yd) */
      r1 = r2 - t1;
      /* (xa - xc) + (yb - yd) */
      r2 = r2 + t1;

      /* (ya - yc) + (xb - xd) */
      s1 = s2 + t2;
      /* (ya - yc) - (xb - xd) */
      s2 = s2 - t2;

      co1 = pCoef[ia1 * 2u];
      si1 = pCoef[(ia1 * 2u) + 1u];

      /* xb' = (xa+yb-xc-yd)co1 - (ya-xb-yc+xd)(si1) */
      pSrc[2u * i2] = (((int32_t) (((q63_t) r1 * co1) >> 32)) -
                       ((int32_t) (((q63_t) s1 * si1) >> 32))) << 1u;

      /* yb' = (ya-xb-yc+xd)co1 + (xa+yb-xc-yd)(si1) */
      pSrc[(2u * i2) + 1u] = (((int32_t) (((q63_t) s1 * co1) >> 32)) +
                              ((int32_t) (((q63_t) r1 * si1) >> 32))) << 1u;

      /*  index calculation for the coefficients */
      ia3 = 3u * ia1;
      co3 = pCoef[ia3 * 2u];
      si3 = pCoef[(ia3 * 2u) + 1u];

      /* xd' = (xa-yb-xc+yd)co3 - (ya+xb-yc-xd)(si3) */
      pSrc[2u * i3] = (((int32_t) (((q63_t) r2 * co3) >> 32)) -
                       ((int32_t) (((q63_t) s2 * si3) >> 32))) << 1u;

      /* yd' = (ya+xb-yc-xd)co3 + (xa-yb-xc+yd)(si3) */
      pSrc[(2u * i3) + 1u] = (((int32_t) (((q63_t) s2 * co3) >> 32)) +
                              ((int32_t) (((q63_t) r2 * si3) >> 32))) << 1u;

      /*  Twiddle coefficients index modifier */
      ia1 = ia1 + twidCoefModifier;

      /*  Updating input index */
      i0 = i0 + 1u;

    } while(--j);

    /* data is in 5.27(q27) format */
    /* each stage provides two down scaling of the input */


    /* Start of Middle stages process */

    twidCoefModifier <<= 2u;

    /*  Calculation of second stage to excluding last stage */
    for (k = fftLen / 4u; k > 4u; k >>= 2u)
    {
      /*  Initializations for the first stage */
      n1 = n2;
      n2 >>= 2u;
      ia1 = 0u;

      for (j = 0; j <= (n2 - 1u); j++)
      {
        /*  index calculation for the coefficients */
        ia2 = ia1 + ia1;
        ia3 = ia2 + ia1;
        co1 = pCoef[ia1 * 2u];
        si1 = pCoef[(ia1 * 2u) + 1u];
        co2 = pCoef[ia2 * 2u];
        si2 = pCoef[(ia2 * 2u) + 1u];
        co3 = pCoef[ia3 * 2u];
        si3 = pCoef[(ia3 * 2u) + 1u];
        /*  Twiddle coefficients index modifier */
        ia1 = ia1 + twidCoefModifier;

        for (i0 = j; i0 < fftLen; i0 += n1)
        {
          /*  index calculation for the input as, */
          /*  pSrc[i0 + 0], pSrc[i0 + fftLen/4], pSrc[i0 + fftLen/2u], pSrc[i0 + 3fftLen/4] */
          i1 = i0 + n2;
          i2 = i1 + n2;
          i3 = i2 + n2;

          /*  Butterfly implementation */
          /* xa + xc */
          r1 = pSrc[2u * i0] + pSrc[2u * i2];
          /* xa - xc */
          r2 = pSrc[2u * i0] - pSrc[2u * i2];

          /* ya + yc */
          s1 = pSrc[(2u * i0) + 1u] + pSrc[(2u * i2) + 1u];
          /* ya - yc */
          s2 = pSrc[(2u * i0) + 1u] - pSrc[(2u * i2) + 1u];

          /* xb + xd */
          t1 = pSrc[2u * i1] + pSrc[2u * i3];

          /* xa' = xa + xb + xc + xd */
          pSrc[2u * i0] = (r1 + t1) >> 2u;
          /* xa + xc -(xb + xd) */
          r1 = r1 - t1;
          /* yb + yd */
          t2 = pSrc[(2u * i1) + 1u] + pSrc[(2u * i3) + 1u];
          /* ya' = ya + yb + yc + yd */
          pSrc[(2u * i0) + 1u] = (s1 + t2) >> 2u;

          /* (ya + yc) - (yb + yd) */
          s1 = s1 - t2;

          /* (yb - yd) */
          t1 = pSrc[(2u * i1) + 1u] - pSrc[(2u * i3) + 1u];
          /* (xb - xd) */
          t2 = pSrc[2u * i1] - pSrc[2u * i3];

          /* xc' = (xa-xb+xc-xd)co2 - (ya-yb+yc-yd)(si2) */
          pSrc[2u * i1] = (((int32_t) (((q63_t) r1 * co2) >> 32u)) -
                           ((int32_t) (((q63_t) s1 * si2) >> 32u))) >> 1u;

          /* yc' = (ya-yb+yc-yd)co2 + (xa-xb+xc-xd)(si2) */
          pSrc[(2u * i1) + 1u] =
            (((int32_t) (((q63_t) s1 * co2) >> 32u)) +
             ((int32_t) (((q63_t) r1 * si2) >> 32u))) >> 1u;

          /* (xa - xc) - (yb - yd) */
          r1 = r2 - t1;
          /* (xa - xc) + (yb - yd) */
          r2 = r2 + t1;

          /* (ya - yc) +  (xb - xd) */
          s1 = s2 + t2;
          /* (ya - yc) -  (xb - xd) */
          s2 = s2 - t2;

          /* xb' = (xa+yb-xc-yd)co1 - (ya-xb-yc+xd)(si1) */
          pSrc[2u * i2] = (((int32_t) (((q63_t) r1 * co1) >> 32)) -
                           ((int32_t) (((q63_t) s1 * si1) >> 32))) >> 1u;

          /* yb' = (ya-xb-yc+xd)co1 + (xa+yb-xc-yd)(si1) */
          pSrc[(2u * i2) + 1u] = (((int32_t) (((q63_t) s1 * co1) >> 32)) +
                                  ((int32_t) (((q63_t) r1 * si1) >> 32))) >> 1u;

          /* xd' = (xa-yb-xc+yd)co3 - (ya+xb-yc-xd)(si3) */
          pSrc[(2u * i3)] = (((int32_t) (((q63_t) r2 * co3) >> 32)) -
                             ((int32_t) (((q63_t) s2 * si3) >> 32))) >> 1u;

          /* yd' = (ya+xb-yc-xd)co3 + (xa-yb-xc+yd)(si3) */
          pSrc[(2u * i3) + 1u] = (((int32_t) (((q63_t) s2 * co3) >> 32)) +
                                  ((int32_t) (((q63_t) r2 * si3) >> 32))) >> 1u;
        }
      }
      twidCoefModifier <<= 2u;
    }

    /* End of Middle stages process */

    /* data is in 11.21(q21) format for the 1024 point as there are 3 middle stages */
    /* data is in 9.23(q23) format for the 256 point as there are 2 middle stages */
    /* data is in 7.25(q25) format for the 64 point as there are 1 middle stage */
    /* data is in 5.27(q27) format for the 16 point as there are no middle stages */


    /* Start of last stage process */


    /*  Initializations for the last stage */
    j = fftLen >> 2;
    ptr1 = &pSrc[0];

    /*  Calculations of last stage */
    do
    {
      /* Read xa (real), ya(imag) input */
      xa = *ptr1++;
      ya = *ptr1++;

      /* Read xb (real), yb(imag) input */
      xb = *ptr1++;
      yb = *ptr1++;

      /* Read xc (real), yc(imag) input */
      xc = *ptr1++;
      yc = *ptr1++;

      /* Read xc (real), yc(imag) input */
      xd = *ptr1++;
      yd = *ptr1++;



      /* xa' = xa + xb + xc + xd */
      xa_out = xa + xb + xc + xd;

      /* ya' = ya + yb + yc + yd */
      ya_out = ya + yb + yc + yd;

      /* pointer updation for writing */
      ptr1 = ptr1 - 8u;

      /* writing xa' and ya' */
      *ptr1++ = xa_out;
      *ptr1++ = ya_out;

      xc_out = (xa - xb + xc - xd);
      yc_out = (ya - yb + yc - yd);

      /* writing xc' and yc' */
      *ptr1++ = xc_out;
      *ptr1++ = yc_out;

      xb_out = (xa - yb - xc + yd);
      yb_out = (ya + xb - yc - xd);

      /* writing xb' and yb' */
      *ptr1++ = xb_out;
      *ptr1++ = yb_out;

      xd_out = (xa + yb - xc - yd);
      yd_out = (ya - xb - yc + xd);

      /* writing xd' and yd' */
      *ptr1++ = xd_out;
      *ptr1++ = yd_out;

    } while(--j);

    /* output is in 11.21(q21) format for the 1024 point */
    /* output is in 9.23(q23) format for the 256 point */
    /* output is in 7.25(q25) format for the 64 point */
    /* output is in 5.27(q27) format for the 16 point */

    /* End of last stage process */
}

void arm_cfft_radix4by2_inverse_q31(
    q31_t * pSrc,
    uint32_t fftLen,
    const q31_t * pCoef)
{
    uint32_t i, l;
    uint32_t n2, ia;
    q31_t xt, yt, cosVal, sinVal;
    q31_t p0, p1;

    n2 = fftLen >> 1;
    ia = 0;
    for (i = 0; i < n2; i++)
    {
        cosVal = pCoef[2*ia];
        sinVal = pCoef[2*ia + 1];
        ia++;

        l = i + n2;
        xt = (pSrc[2 * i] >> 2) - (pSrc[2 * l] >> 2);
        pSrc[2 * i] = (pSrc[2 * i] >> 2) + (pSrc[2 * l] >> 2);

        yt = (pSrc[2 * i + 1] >> 2) - (pSrc[2 * l + 1] >> 2);
        pSrc[2 * i + 1] = (pSrc[2 * l + 1] >> 2) + (pSrc[2 * i + 1] >> 2);

        mult_32x32_keep32_R(p0, xt, cosVal);
        mult_32x32_keep32_R(p1, yt, cosVal);
        multSub_32x32_keep32_R(p0, yt, sinVal);
        multAcc_32x32_keep32_R(p1, xt, sinVal);

        pSrc[2u * l] = p0 << 1;
        pSrc[2u * l + 1u] = p1 << 1;

    }

    // first col
    arm_radix4_butterfly_inverse_q31( pSrc, n2, (q31_t*)pCoef, 2u);
    // second col
    arm_radix4_butterfly_inverse_q31( pSrc + fftLen, n2, (q31_t*)pCoef, 2u);

    for (i = 0; i < fftLen >> 1; i++)
    {
        p0 = pSrc[4*i+0];
        p1 = pSrc[4*i+1];
        xt = pSrc[4*i+2];
        yt = pSrc[4*i+3];

        p0 <<= 1;
        p1 <<= 1;
        xt <<= 1;
        yt <<= 1;

        pSrc[4*i+0] = p0;
        pSrc[4*i+1] = p1;
        pSrc[4*i+2] = xt;
        pSrc[4*i+3] = yt;
    }
}


/**
 * @} end of ComplexFFT group
 */

/*
* Radix-4 FFT algorithm used is :
*
* Input real and imaginary data:
* x(n) = xa + j * ya
* x(n+N/4 ) = xb + j * yb
* x(n+N/2 ) = xc + j * yc
* x(n+3N 4) = xd + j * yd
*
*
* Output real and imaginary data:
* x(4r) = xa'+ j * ya'
* x(4r+1) = xb'+ j * yb'
* x(4r+2) = xc'+ j * yc'
* x(4r+3) = xd'+ j * yd'
*
*
* Twiddle factors for radix-4 FFT:
* Wn = co1 + j * (- si1)
* W2n = co2 + j * (- si2)
* W3n = co3 + j * (- si3)
*
*  Butterfly implementation:
* xa' = xa + xb + xc + xd
* ya' = ya + yb + yc + yd
* xb' = (xa+yb-xc-yd)* co1 + (ya-xb-yc+xd)* (si1)
* yb' = (ya-xb-yc+xd)* co1 - (xa+yb-xc-yd)* (si1)
* xc' = (xa-xb+xc-xd)* co2 + (ya-yb+yc-yd)* (si2)
* yc' = (ya-yb+yc-yd)* co2 - (xa-xb+xc-xd)* (si2)
* xd' = (xa-yb-xc+yd)* co3 + (ya+xb-yc-xd)* (si3)
* yd' = (ya+xb-yc-xd)* co3 - (xa-yb-xc+yd)* (si3)
*
*/

/**
 * @brief  Core function for the Q31 CFFT butterfly process.
 * @param[in, out] *pSrc            points to the in-place buffer of Q31 data type.
 * @param[in]      fftLen           length of the FFT.
 * @param[in]      *pCoef           points to twiddle coefficient buffer.
 * @param[in]      twidCoefModifier twiddle coefficient modifier that supports different size FFTs with the same twiddle factor table.
 * @return none.
 */

static void arm_radix4_butterfly_q31(
    q31_t * pSrc,
    uint32_t fftLen,
    const q31_t * pCoef,
    uint32_t twidCoefModifier
)
{
    printf("Entering arm_radix4_butterfly_q31, fftLen is %d\n",fftLen);
    uint32_t n1, n2, ia1, ia2, ia3, i0, i1, i2, i3, j, k;
    q31_t t1, t2, r1, r2, s1, s2, co1, co2, co3, si1, si2, si3;

    q31_t xa, xb, xc, xd;
    q31_t ya, yb, yc, yd;
    q31_t xa_out, xb_out, xc_out, xd_out;
    q31_t ya_out, yb_out, yc_out, yd_out;

    q31_t *ptr1;

    /* Total process is divided into three stages */

    /* process first stage, middle stages, & last stage */


    /* start of first stage process */

    /*  Initializations for the first stage */
    n2 = fftLen;
    n1 = n2;
    /* n2 = fftLen/4 */
    n2 >>= 2u;
    i0 = 0u;
    ia1 = 0u;

    j = n2;

    /*  Calculation of first stage */
    printf("--------------------------------------------------\n");
    printf("First stage:\n");
    do
    {
      /*  index calculation for the input as, */
      /*  pSrc[i0 + 0], pSrc[i0 + fftLen/4], pSrc[i0 + fftLen/2u], pSrc[i0 + 3fftLen/4] */
      i1 = i0 + n2;
      i2 = i1 + n2;
      i3 = i2 + n2;

      /* input is in 1.31(q31) format and provide 4 guard bits for the input */
    printf("Loop %d:\n",j);
    printf("data: pSrc[%d], pSrc[%d], pSrc[%d], pSrc[%d]\n",i0, i1, i2, i3);
    printf("in: %d,%d\t%d,%d\t%d,%d\t%d,%d\t\n",pSrc[2u * i0], pSrc[(2u * i0) + 1u],pSrc[2u * i1], pSrc[(2u * i1) + 1u],pSrc[2u * i2], pSrc[(2u * i2) + 1u],pSrc[2u * i3], pSrc[(2u * i3) + 1u]);

      /*  Butterfly implementation */
      /* xa + xc */
      r1 = (pSrc[(2u * i0)] >> 4u) + (pSrc[(2u * i2)] >> 4u);
      /* xa - xc */
      r2 = (pSrc[2u * i0] >> 4u) - (pSrc[2u * i2] >> 4u);

      /* xb + xd */
      t1 = (pSrc[2u * i1] >> 4u) + (pSrc[2u * i3] >> 4u);

      /* ya + yc */
      s1 = (pSrc[(2u * i0) + 1u] >> 4u) + (pSrc[(2u * i2) + 1u] >> 4u);
      /* ya - yc */
      s2 = (pSrc[(2u * i0) + 1u] >> 4u) - (pSrc[(2u * i2) + 1u] >> 4u);

      /* xa' = xa + xb + xc + xd */
      pSrc[2u * i0] = (r1 + t1);
      /* (xa + xc) - (xb + xd) */
      r1 = r1 - t1;
      /* yb + yd */
      t2 = (pSrc[(2u * i1) + 1u] >> 4u) + (pSrc[(2u * i3) + 1u] >> 4u);

      /* ya' = ya + yb + yc + yd */
      pSrc[(2u * i0) + 1u] = (s1 + t2);

      /* (ya + yc) - (yb + yd) */
      s1 = s1 - t2;

      /* yb - yd */
      t1 = (pSrc[(2u * i1) + 1u] >> 4u) - (pSrc[(2u * i3) + 1u] >> 4u);
      /* xb - xd */
      t2 = (pSrc[2u * i1] >> 4u) - (pSrc[2u * i3] >> 4u);

      /*  index calculation for the coefficients */
      ia2 = 2u * ia1;
      co2 = pCoef[ia2 * 2u];
      si2 = pCoef[(ia2 * 2u) + 1u];

      /* xc' = (xa-xb+xc-xd)co2 + (ya-yb+yc-yd)(si2) */
      pSrc[2u * i1] = (((int32_t) (((q63_t) r1 * co2) >> 32)) +
                       ((int32_t) (((q63_t) s1 * si2) >> 32))) << 1u;

      /* yc' = (ya-yb+yc-yd)co2 - (xa-xb+xc-xd)(si2) */
      pSrc[(2u * i1) + 1u] = (((int32_t) (((q63_t) s1 * co2) >> 32)) -
                              ((int32_t) (((q63_t) r1 * si2) >> 32))) << 1u;

      /* (xa - xc) + (yb - yd) */
      r1 = r2 + t1;
      /* (xa - xc) - (yb - yd) */
      r2 = r2 - t1;

      /* (ya - yc) - (xb - xd) */
      s1 = s2 - t2;
      /* (ya - yc) + (xb - xd) */
      s2 = s2 + t2;

      co1 = pCoef[ia1 * 2u];
      si1 = pCoef[(ia1 * 2u) + 1u];

      /* xb' = (xa+yb-xc-yd)co1 + (ya-xb-yc+xd)(si1) */
      pSrc[2u * i2] = (((int32_t) (((q63_t) r1 * co1) >> 32)) +
                       ((int32_t) (((q63_t) s1 * si1) >> 32))) << 1u;

      /* yb' = (ya-xb-yc+xd)co1 - (xa+yb-xc-yd)(si1) */
      pSrc[(2u * i2) + 1u] = (((int32_t) (((q63_t) s1 * co1) >> 32)) -
                              ((int32_t) (((q63_t) r1 * si1) >> 32))) << 1u;

      /*  index calculation for the coefficients */
      ia3 = 3u * ia1;
      co3 = pCoef[ia3 * 2u];
      si3 = pCoef[(ia3 * 2u) + 1u];
      printf("coefficients : wn1[%d], wn2[%d], wn3[%d]\n",ia1, ia2, ia3);

      /* xd' = (xa-yb-xc+yd)co3 + (ya+xb-yc-xd)(si3) */
      pSrc[2u * i3] = (((int32_t) (((q63_t) r2 * co3) >> 32)) +
                       ((int32_t) (((q63_t) s2 * si3) >> 32))) << 1u;

      /* yd' = (ya+xb-yc-xd)co3 - (xa-yb-xc+yd)(si3) */
      pSrc[(2u * i3) + 1u] = (((int32_t) (((q63_t) s2 * co3) >> 32)) -
                              ((int32_t) (((q63_t) r2 * si3) >> 32))) << 1u;

      /*  Twiddle coefficients index modifier */
      ia1 = ia1 + twidCoefModifier;

      /*  Updating input index */
      printf("out: %d,%d\t%d,%d\t%d,%d\t%d,%d\t\n\n",pSrc[2u * i0], pSrc[(2u * i0) + 1u],pSrc[2u * i1], pSrc[(2u * i1) + 1u],pSrc[2u * i2], pSrc[(2u * i2) + 1u],pSrc[2u * i3], pSrc[(2u * i3) + 1u]);

      i0 = i0 + 1u;

    } while(--j);

    /* end of first stage process */

    /* data is in 5.27(q27) format */


    /* start of Middle stages process */


    /* each stage in middle stages provides two down scaling of the input */

    twidCoefModifier <<= 2u;

    int layer = 0;
    for (k = fftLen / 4u; k > 4u; k >>= 2u)
    {
      /*  Initializations for the first stage */
      n1 = n2;
      n2 >>= 2u;
      ia1 = 0u;
      printf("--------------------------------------------------\n");
      printf("Middle Stage: %d\n",layer);
      layer++;

      /*  Calculation of first stage */
      for (j = 0u; j <= (n2 - 1u); j++)
      {
        /*  index calculation for the coefficients */
        ia2 = ia1 + ia1;
        ia3 = ia2 + ia1;
        co1 = pCoef[ia1 * 2u];
        si1 = pCoef[(ia1 * 2u) + 1u];
        co2 = pCoef[ia2 * 2u];
        si2 = pCoef[(ia2 * 2u) + 1u];
        co3 = pCoef[ia3 * 2u];
        si3 = pCoef[(ia3 * 2u) + 1u];
        printf("Loop %d:\n",j);
        printf("coefficients : wn1[%d], wn2[%d], wn3[%d]\n",ia1, ia2, ia3);

        /*  Twiddle coefficients index modifier */
        ia1 = ia1 + twidCoefModifier;

        for (i0 = j; i0 < fftLen; i0 += n1)
        {
          /*  index calculation for the input as, */
          /*  pSrc[i0 + 0], pSrc[i0 + fftLen/4], pSrc[i0 + fftLen/2u], pSrc[i0 + 3fftLen/4] */
          i1 = i0 + n2;
          i2 = i1 + n2;
          i3 = i2 + n2;
          printf("data: pSrc[%d], pSrc[%d], pSrc[%d], pSrc[%d]\n",i0, i1, i2, i3);
          printf("in: %d,%d\t%d,%d\t%d,%d\t%d,%d\t\n",pSrc[2u * i0], pSrc[(2u * i0) + 1u],pSrc[2u * i1], pSrc[(2u * i1) + 1u],pSrc[2u * i2], pSrc[(2u * i2) + 1u],pSrc[2u * i3], pSrc[(2u * i3) + 1u]);


          /*  Butterfly implementation */
          /* xa + xc */
          r1 = pSrc[2u * i0] + pSrc[2u * i2];
          /* xa - xc */
          r2 = pSrc[2u * i0] - pSrc[2u * i2];

          /* ya + yc */
          s1 = pSrc[(2u * i0) + 1u] + pSrc[(2u * i2) + 1u];
          /* ya - yc */
          s2 = pSrc[(2u * i0) + 1u] - pSrc[(2u * i2) + 1u];

          /* xb + xd */
          t1 = pSrc[2u * i1] + pSrc[2u * i3];

          /* xa' = xa + xb + xc + xd */
          pSrc[2u * i0] = (r1 + t1) >> 2u;
          /* xa + xc -(xb + xd) */
          r1 = r1 - t1;

          /* yb + yd */
          t2 = pSrc[(2u * i1) + 1u] + pSrc[(2u * i3) + 1u];
          /* ya' = ya + yb + yc + yd */
          pSrc[(2u * i0) + 1u] = (s1 + t2) >> 2u;

          /* (ya + yc) - (yb + yd) */
          s1 = s1 - t2;

          /* (yb - yd) */
          t1 = pSrc[(2u * i1) + 1u] - pSrc[(2u * i3) + 1u];
          /* (xb - xd) */
          t2 = pSrc[2u * i1] - pSrc[2u * i3];

          /* xc' = (xa-xb+xc-xd)co2 + (ya-yb+yc-yd)(si2) */
          pSrc[2u * i1] = (((int32_t) (((q63_t) r1 * co2) >> 32)) +
                           ((int32_t) (((q63_t) s1 * si2) >> 32))) >> 1u;

          /* yc' = (ya-yb+yc-yd)co2 - (xa-xb+xc-xd)(si2) */
          pSrc[(2u * i1) + 1u] = (((int32_t) (((q63_t) s1 * co2) >> 32)) -
                                  ((int32_t) (((q63_t) r1 * si2) >> 32))) >> 1u;

          /* (xa - xc) + (yb - yd) */
          r1 = r2 + t1;
          /* (xa - xc) - (yb - yd) */
          r2 = r2 - t1;

          /* (ya - yc) -  (xb - xd) */
          s1 = s2 - t2;
          /* (ya - yc) +  (xb - xd) */
          s2 = s2 + t2;

          /* xb' = (xa+yb-xc-yd)co1 + (ya-xb-yc+xd)(si1) */
          pSrc[2u * i2] = (((int32_t) (((q63_t) r1 * co1) >> 32)) +
                           ((int32_t) (((q63_t) s1 * si1) >> 32))) >> 1u;

          /* yb' = (ya-xb-yc+xd)co1 - (xa+yb-xc-yd)(si1) */
          pSrc[(2u * i2) + 1u] = (((int32_t) (((q63_t) s1 * co1) >> 32)) -
                                  ((int32_t) (((q63_t) r1 * si1) >> 32))) >> 1u;

          /* xd' = (xa-yb-xc+yd)co3 + (ya+xb-yc-xd)(si3) */
          pSrc[2u * i3] = (((int32_t) (((q63_t) r2 * co3) >> 32)) +
                           ((int32_t) (((q63_t) s2 * si3) >> 32))) >> 1u;

          /* yd' = (ya+xb-yc-xd)co3 - (xa-yb-xc+yd)(si3) */
          pSrc[(2u * i3) + 1u] = (((int32_t) (((q63_t) s2 * co3) >> 32)) -
                                  ((int32_t) (((q63_t) r2 * si3) >> 32))) >> 1u;

        printf("out: %d,%d\t%d,%d\t%d,%d\t%d,%d\t\n\n",pSrc[2u * i0], pSrc[(2u * i0) + 1u],pSrc[2u * i1], pSrc[(2u * i1) + 1u],pSrc[2u * i2], pSrc[(2u * i2) + 1u],pSrc[2u * i3], pSrc[(2u * i3) + 1u]);
        }
      }
      twidCoefModifier <<= 2u;
    }

    /* End of Middle stages process */

    /* data is in 11.21(q21) format for the 1024 point as there are 3 middle stages */
    /* data is in 9.23(q23) format for the 256 point as there are 2 middle stages */
    /* data is in 7.25(q25) format for the 64 point as there are 1 middle stage */
    /* data is in 5.27(q27) format for the 16 point as there are no middle stages */


    /* start of Last stage process */
    /*  Initializations for the last stage */

    j = fftLen >> 2;
    ptr1 = &pSrc[0];

    printf("--------------------------------------------------\n");
    printf("Last Stage\n");

    /*  Calculations of last stage */
    do
    {
      printf("Loop %d: output 4 data\n",j);

      /* Read xa (real), ya(imag) input */
      xa = *ptr1++;
      ya = *ptr1++;

      /* Read xb (real), yb(imag) input */
      xb = *ptr1++;
      yb = *ptr1++;

      /* Read xc (real), yc(imag) input */
      xc = *ptr1++;
      yc = *ptr1++;

      /* Read xc (real), yc(imag) input */
      xd = *ptr1++;
      yd = *ptr1++;


      /* xa' = xa + xb + xc + xd */
      xa_out = xa + xb + xc + xd;

      /* ya' = ya + yb + yc + yd */
      ya_out = ya + yb + yc + yd;

      /* pointer updation for writing */
      ptr1 = ptr1 - 8u;

      /* writing xa' and ya' */
      *ptr1++ = xa_out;
      *ptr1++ = ya_out;

      xc_out = (xa - xb + xc - xd);
      yc_out = (ya - yb + yc - yd);

      /* writing xc' and yc' */
      *ptr1++ = xc_out;
      *ptr1++ = yc_out;

      xb_out = (xa + yb - xc - yd);
      yb_out = (ya - xb - yc + xd);

      /* writing xb' and yb' */
      *ptr1++ = xb_out;
      *ptr1++ = yb_out;

      xd_out = (xa - yb - xc + yd);
      yd_out = (ya + xb - yc - xd);

      /* writing xd' and yd' */
      *ptr1++ = xd_out;
      *ptr1++ = yd_out;


    } while(--j);

    /* output is in 11.21(q21) format for the 1024 point */
    /* output is in 9.23(q23) format for the 256 point */
    /* output is in 7.25(q25) format for the 64 point */
    /* output is in 5.27(q27) format for the 16 point */

    /* End of last stage process */
}

void arm_cfft_radix4by2_q31(
    q31_t * pSrc,
    uint32_t fftLen,
    const q31_t * pCoef)
{
    uint32_t i, l;
    uint32_t n2, ia;
    q31_t xt, yt, cosVal, sinVal;
    q31_t p0, p1;

    n2 = fftLen >> 1;
    ia = 0;
    for (i = 0; i < n2; i++)
    {
        cosVal = pCoef[2*ia];
        sinVal = pCoef[2*ia + 1];
        ia++;

        l = i + n2;
        xt = (pSrc[2 * i] >> 2) - (pSrc[2 * l] >> 2);
        pSrc[2 * i] = (pSrc[2 * i] >> 2) + (pSrc[2 * l] >> 2);

        yt = (pSrc[2 * i + 1] >> 2) - (pSrc[2 * l + 1] >> 2);
        pSrc[2 * i + 1] = (pSrc[2 * l + 1] >> 2) + (pSrc[2 * i + 1] >> 2);

        mult_32x32_keep32_R(p0, xt, cosVal);
        mult_32x32_keep32_R(p1, yt, cosVal);
        multAcc_32x32_keep32_R(p0, yt, sinVal);
        multSub_32x32_keep32_R(p1, xt, sinVal);

        pSrc[2u * l] = p0 << 1;
        pSrc[2u * l + 1u] = p1 << 1;

    }

    // first col
    arm_radix4_butterfly_q31( pSrc, n2, (q31_t*)pCoef, 2u);
    // second col
    arm_radix4_butterfly_q31( pSrc + fftLen, n2, (q31_t*)pCoef, 2u);

    for (i = 0; i < fftLen >> 1; i++)
    {
        p0 = pSrc[4*i+0];
        p1 = pSrc[4*i+1];
        xt = pSrc[4*i+2];
        yt = pSrc[4*i+3];

        p0 <<= 1;
        p1 <<= 1;
        xt <<= 1;
        yt <<= 1;

        pSrc[4*i+0] = p0;
        pSrc[4*i+1] = p1;
        pSrc[4*i+2] = xt;
        pSrc[4*i+3] = yt;
    }

}


void arm_bitreversal_32(
    uint32_t *pSrc,
    const uint16_t bitRevLen,
    const uint16_t *pBitRevTab
){
    uint32_t a, b, i, tmp;

    for(i = 0; i< bitRevLen;)
    {
        a = pBitRevTab[i] >> 2;
        b = pBitRevTab[i+1] >> 2;

        //real
        tmp = pSrc[a];
        pSrc[a] = pSrc[b];
        pSrc[b] = tmp;

        //complex
        tmp = pSrc[a+1];
        pSrc[a] = pSrc[b+1];
        pSrc[b] = tmp;

        i+=2;
    }
}

/**
* @details
* @brief       Processing function for the fixed-point complex FFT in Q31 format.
* @param[in]      *S    points to an instance of the fixed-point CFFT structure.
* @param[in, out] *p1   points to the complex data buffer of size <code>2*fftLen</code>. Processing occurs in-place.
* @param[in]     ifftFlag       flag that selects forward (ifftFlag=0) or inverse (ifftFlag=1) transform.
* @param[in]     bitReverseFlag flag that enables (bitReverseFlag=1) or disables (bitReverseFlag=0) bit reversal of output.
* @return none.
*/

void arm_cfft_q31(
    const arm_cfft_instance_q31 * S,
    q31_t * p1,
    uint8_t ifftFlag,
    uint8_t bitReverseFlag)
{
    uint32_t L = S->fftLen;
    if(ifftFlag == 1u)
    {
        switch (L)
        {
        case 16:
        case 64:
        case 256:
        case 1024:
        case 4096:
            arm_radix4_butterfly_inverse_q31  ( p1, L, (q31_t*)S->pTwiddle, 1 );
            break;

        case 32:
        case 128:
        case 512:
        case 2048:
            arm_cfft_radix4by2_inverse_q31  ( p1, L, S->pTwiddle );
            break;
        }
    }
    else
    {
        switch (L)
        {
        case 16:
        case 64:
        case 256:
        case 1024:
        case 4096:
            arm_radix4_butterfly_q31  ( p1, L, (q31_t*)S->pTwiddle, 1 );
            break;

        case 32:
        case 128:
        case 512:
        case 2048:
            arm_cfft_radix4by2_q31  ( p1, L, S->pTwiddle );
            break;
        }
    }

    if( bitReverseFlag )
        arm_bitreversal_32((uint32_t*)p1,S->bitRevLength,S->pBitRevTable);
}

/**
* @} end of ComplexFFT group
*/


const q31_t fixed_random_input_no_zero[128] = {
    123456789, -987654321,  456789123, -321654987,  789123456, -654987321, 135792468, -987654123,
    246813579, -135792468,  987654321, -246813579, 543216789, -123987654,  789654123, -654321987,
    321987654, -789321456,  987123654, -456789321, 654789123, -321654789,  135987246, -987135642,
    246579813, -135468297,  987312654, -246579138, 543789216, -123654987,  789312456, -654987321,
    321654987, -789456123,  987321654, -456789321, 654789321, -321987654,  135987321, -987135987,
    246579987, -135468579,  987312789, -246579789, 543789789, -123654789,  789312987, -654987987,
    321654789, -789456789,  987321987, -456789987, 654789987, -321987987,  135987987, -987135135,
    246579135, -135468135,  987312135, -246579135, 543789135, -123654135,  789312135, -654987135,
    -102345678,  876543210, -567891234,  432165987, -891234567,  765432189, -357924681,  876543219,
    -468135792,  357924681, -876543210,  468135792, -432167890,  123789654, -876543123,  432198765,
    -219876543,  789432165, -987654123,  654321789, -321789456,  987654321, -135789246,  987135642,
    -579813246,  468297135, -312654987,  579138246, -789216543,  654987123, -312456789,  987321654,
    -654987321,  456123789, -321654987,  987654123, -789321654,  321987654, -987321135,  135987987,
    -579987246,  468579135, -312789987,  579789246, -789789543,  654789123, -312987789,  987987654,
    -654789321,  456789987, -321987654,  789789456, -987987321,  987321987, -135135987,  135987135,
    -579135246,  468135579, -312135789,  579135987, -789135543,  654135789, -312135987,  987135654
};



#define FFT_LEN 64  // FFT 长度

// **完整的 64 点 Twiddle 因子表（128 个值 = 64 组复数对）**

const q31_t twiddleCoef_64_q31[128] = {
    2147483647, 0,
    2144908958, -26352928,
    2137228653, -52681350,
    2124361362, -78960702,
    2106310695, -105162053,
    2083088875, -131192721,
    2054716921, -157072648,
    2021224546, -182758063,
    1982640161, -208204363,
    1939000875, -233366758,
    1890352491, -258200060,
    1836749327, -282659825,
    1778254152, -306701660,
    1714938165, -330281227,
    1646880912, -353354263,
    1574170155, -375876725,
    1496901786, -397804916,
    1415179620, -419095607,
    1329115439, -439706187,
    1238828824, -459594801,
    1144447016, -478720396,
    1046079309, -497205191,
    947842739, -515104469,
    847882308, -532374860,
    745745374, -548973502,
    641605887, -564858947,
    535644392, -579991181,
    428047651, -594331619,
    319008454, -607843024,
    208725615, -620489517,
    97404968, -632236541,
    -14480397, -643050789,
    -126324984, -652900272,
    -238632379, -661754289,
    -351062708, -669584393,
    -463404568, -676364484,
    -575448056, -682070017,
    -686984847, -686678754,
    -797808405, -690170884,
    -907714168, -692528963,
    -1016529954, -693738902,
    -1123848927, -693789959,
    -1229470410, -692674736,
    -1333164786, -690389160,
    -1434704762, -686932487,
    -1533866064, -682307267,
    -1630428023, -676519332,
    -1724174051, -669577771,
    -1814892334, -661494893,
    -1902376480, -652286201,
    -1986426071, -641970319,
    -2066847435, -630568935,
    -2143453803, -618106718,
    -2216065586, -604611206,
    -2284510682, -590112714,
    -2348624781, -574644254,
    -2408251593, -558241448,
    -2463242960, -540942416,
    -2513459004, -522787666,
    -2558768357, -503819012,
    -2599048316, -484080475,
    -2634185012, -463618171,
    -2664073598, -442480172,
    -2688618553, -420716366,
    -2707733725, -398378336,
    -2721342475, -375519206,
    -2729377776, -352193499,
    -2731782292, -328457003,
    -2728508488, -304366638,
    -2719518620, -279980285,
    -2704784716, -255356612,
    -2684288612, -230554940,
    -2658021983, -205635062,
    -2625986285, -180657082,
    -2588192728, -155681271,
    -2544662267, -130767880,
    -2495425493, -105976980,
    -2440522518, -81368576,
    -2380002905, -57027012,
    -2313925436, -32924178,
    -2242358065, -9090712,
    -2165377857, 14114696,
    -2083070752, 37246293,
    -1995531437, 60116388,
    -1902863125, 82725040,
    -1805177351, 105078710,
    -1702593708, 127070531,
    -1595249576, 148689373,
    -1483299742, 169914863,
    -1366916009, 190727088,
    -1246286904, 211106664,
    -1121617248, 231034810,
    -993124545, 250493339,
    -860107185, 269464737,
    -724888630, 287932214,
    -587589431, 305879718,
    -448327994, 323291987,
    -307219742, 340154542,
    -164374169, 356453747,
    -19964337, 372176858
};



// **完整的 64 点 Bit Reverse 索引表**
const uint16_t bitRevIndexTable_64[FFT_LEN] = {
    0, 32, 16, 48, 8, 40, 24, 56,
    4, 36, 20, 52, 12, 44, 28, 60,
    2, 34, 18, 50, 10, 42, 26, 58,
    6, 38, 22, 54, 14, 46, 30, 62,
    1, 33, 17, 49, 9, 41, 25, 57,
    5, 37, 21, 53, 13, 45, 29, 61,
    3, 35, 19, 51, 11, 43, 27, 59,
    7, 39, 23, 55, 15, 47, 31, 63
};

int32_t get_fixed_random_number() { 
    return ((rand() << 16) | rand()) & 0x7FFFFFFF; 
} 
void generate_fixed_random_input(q31_t *pSrc) { 
    srand(1); // **固定随机种子** 
    for (int i = 0; i < FFT_LEN; i++) { 
        pSrc[2 * i] = get_fixed_random_number();
        pSrc[2 * i + 1] = get_fixed_random_number(); 
    } 
}

void generate_fixed_random_input_no_zero(q31_t *pSrc) { 
    for (int i = 0; i < FFT_LEN; i++) { 
        pSrc[2 * i] = fixed_random_input_no_zero[2 * i]; // **实部** 
        pSrc[2 * i + 1] = fixed_random_input_no_zero[2 * i + 1]; // **虚部** 
        } 
    }

// **自己定义的 64 点 FFT 结构体**
const arm_cfft_instance_q31 my_arm_cfft_sR_q31_len64 = {
    .fftLen = FFT_LEN,
    .pTwiddle = twiddleCoef_64_q31,
    .bitRevLength = 32,  // **64 点 FFT 的 Bit Reverse 长度**
    .pBitRevTable = bitRevIndexTable_64
};

int32_t get_random_number() {
    HCRYPTPROV hCryptProv;
    int32_t random_value;

    if (CryptAcquireContext(&hCryptProv, NULL, NULL, PROV_RSA_FULL, 0)) {
        CryptGenRandom(hCryptProv, sizeof(int32_t), (BYTE *)&random_value);
        CryptReleaseContext(hCryptProv, 0);
    } else {
        random_value = ((rand() << 16) | rand()) & 0x7FFFFFFF;
        if (rand() % 2) random_value = -random_value;
    }

    return random_value;
}

// **转换数值为二进制字符串**
void int_to_binary(int32_t num, char *binary_str) {
    for (int i = 31; i >= 0; i--) {
        binary_str[31 - i] = (num & (1 << i)) ? '1' : '0';
    }
    binary_str[32] = '\0';
}

void run_fft() {
    const arm_cfft_instance_q31 *S = &my_arm_cfft_sR_q31_len64;

    q31_t pSrc[2 * FFT_LEN];
    q31_t pSrc_copy[2 * FFT_LEN];

    // **生成随机输入数据**
    /*
    for (int i = 0; i < FFT_LEN; i++) {
        pSrc[2 * i] = get_random_number();
        pSrc[2 * i + 1] = get_random_number();
        pSrc_copy[2 * i] = pSrc[2 * i];
        pSrc_copy[2 * i + 1] = pSrc[2 * i + 1];
    }
    */
    generate_fixed_random_input_no_zero(pSrc);
    for (int i = 0; i < FFT_LEN; i++) {
        pSrc_copy[2 * i] = pSrc[2 * i];
        pSrc_copy[2 * i + 1] = pSrc[2 * i + 1];
    }

    arm_cfft_q31(S, pSrc, 0, 0);

    // **打开文件**
    FILE *file_input_dec = fopen("fft_input_decimal.txt", "w");
    FILE *file_input_bin = fopen("fft_input_binary.txt", "w");
    FILE *file_output_dec = fopen("fft_output_decimal.txt", "w");
    FILE *file_output_bin = fopen("fft_output_binary.txt", "w");
    FILE *file_twiddle_dec = fopen("fft_twiddle_decimal.txt", "w");
    FILE *file_twiddle_bin = fopen("fft_twiddle_binary.txt", "w");

    if (!file_input_dec || !file_input_bin || !file_output_dec || !file_output_bin || !file_twiddle_dec || !file_twiddle_bin) {
        printf("Error opening file for writing.\n");
        return;
    }

    char binary_str[33];

    // **写入输入数据**
    for (int i = 0; i < FFT_LEN; i++) {
        fprintf(file_input_dec, "%d\n", pSrc_copy[2 * i]);  // 实部
        fprintf(file_input_dec, "%d\n", pSrc_copy[2 * i + 1]);  // 虚部

        int_to_binary(pSrc_copy[2 * i], binary_str);
        fprintf(file_input_bin, "%s\n", binary_str);
        int_to_binary(pSrc_copy[2 * i + 1], binary_str);
        fprintf(file_input_bin, "%s\n", binary_str);
    }

    // **写入 FFT 输出数据**
    for (int i = 0; i < FFT_LEN; i++) {
        fprintf(file_output_dec, "%d\n", pSrc[2 * i]);  // 实部
        fprintf(file_output_dec, "%d\n", pSrc[2 * i + 1]);  // 虚部

        int_to_binary(pSrc[2 * i], binary_str);
        fprintf(file_output_bin, "%s\n", binary_str);
        int_to_binary(pSrc[2 * i + 1], binary_str);
        fprintf(file_output_bin, "%s\n", binary_str);
    }

    // **写入 Twiddle 因子数据**
    for (int i = 0; i < FFT_LEN * 2; i += 2) {
        fprintf(file_twiddle_dec, "%d\n", twiddleCoef_64_q31[i]);  // 实部
        fprintf(file_twiddle_dec, "%d\n", twiddleCoef_64_q31[i + 1]);  // 虚部

        int_to_binary(twiddleCoef_64_q31[i], binary_str);
        fprintf(file_twiddle_bin, "%s\n", binary_str);
        int_to_binary(twiddleCoef_64_q31[i + 1], binary_str);
        fprintf(file_twiddle_bin, "%s\n", binary_str);
    }

    fclose(file_input_dec);
    fclose(file_input_bin);
    fclose(file_output_dec);
    fclose(file_output_bin);
    fclose(file_twiddle_dec);
    fclose(file_twiddle_bin);

    printf("FFT complete! All outputs saved.\n");
}

int main() {
    srand(time(NULL));
    run_fft();
    return 0;
}
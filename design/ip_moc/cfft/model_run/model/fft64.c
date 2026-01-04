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
    printf("--------------------------------------------------\n");
    printf("First stage:\n");
    do
    {

      /* input is in 1.31(q31) format and provide 4 guard bits for the input */

      /*  index calculation for the input as, */
      /*  pSrc[i0 + 0], pSrc[i0 + fftLen/4], pSrc[i0 + fftLen/2u], pSrc[i0 + 3fftLen/4] */
      i1 = i0 + n2;
      i2 = i1 + n2;
      i3 = i2 + n2;
      printf("Loop %d:\n",j);
      printf("data: pSrc[%d], pSrc[%d], pSrc[%d], pSrc[%d]\n",i0, i1, i2, i3);
      printf("in: %d,%d\t%d,%d\t%d,%d\t%d,%d\t\n",pSrc[2u * i0], pSrc[(2u * i0) + 1u],pSrc[2u * i1], pSrc[(2u * i1) + 1u],pSrc[2u * i2], pSrc[(2u * i2) + 1u],pSrc[2u * i3], pSrc[(2u * i3) + 1u]);
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
      printf("coefficients : wn1[%d], wn2[%d], wn3[%d]\n",ia1, ia2, ia3);

      /* xd' = (xa-yb-xc+yd)co3 - (ya+xb-yc-xd)(si3) */
      pSrc[2u * i3] = (((int32_t) (((q63_t) r2 * co3) >> 32)) -
                       ((int32_t) (((q63_t) s2 * si3) >> 32))) << 1u;

      /* yd' = (ya+xb-yc-xd)co3 + (xa-yb-xc+yd)(si3) */
      pSrc[(2u * i3) + 1u] = (((int32_t) (((q63_t) s2 * co3) >> 32)) +
                              ((int32_t) (((q63_t) r2 * si3) >> 32))) << 1u;

      /*  Twiddle coefficients index modifier */
      ia1 = ia1 + twidCoefModifier;

      /*  Updating input index */
      printf("out: %d,%d\t%d,%d\t%d,%d\t%d,%d\t\n\n",pSrc[2u * i0], pSrc[(2u * i0) + 1u],pSrc[2u * i1], pSrc[(2u * i1) + 1u],pSrc[2u * i2], pSrc[(2u * i2) + 1u],pSrc[2u * i3], pSrc[(2u * i3) + 1u]);


      i0 = i0 + 1u;

    } while(--j);

    /* data is in 5.27(q27) format */
    /* each stage provides two down scaling of the input */


    /* Start of Middle stages process */

    twidCoefModifier <<= 2u;

    int layer = 0;
    /*  Calculation of second stage to excluding last stage */
    for (k = fftLen / 4u; k > 4u; k >>= 2u)
    {
      /*  Initializations for the first stage */
      n1 = n2;
      n2 >>= 2u;
      ia1 = 0u;
      printf("--------------------------------------------------\n");
      printf("Middle Stage: %d\n",layer);
      layer++;

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


    /* Start of last stage process */


    /*  Initializations for the last stage */
    j = fftLen >> 2;
    ptr1 = &pSrc[0];

    printf("--------------------------------------------------\n");
    printf("Last Stage\n");

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
      printf("Loop %d: %d,%d,\t%d,%d,\t%d,%d,\t%d,%d,\t\n\n",j,xa_out,ya_out,xc_out,yc_out,xb_out,yb_out,xd_out,yd_out);

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
		printf("cosVal[%d]: %d\tsinVal[%d]: %d\n",2*ia,cosVal,2*ia+1,sinVal);
        ia++;

        l = i + n2;
		printf("pSrc[%d] = %d\t",2*i,pSrc[2 * i]);
		printf("pSrc[%d] = %d\t",2*i+1,pSrc[2 * i+1]);

		printf("pSrc[%d] = %d\t",2*l,pSrc[2 * l]);
		printf("pSrc[%d] = %d\t\n",2*l+1,pSrc[2 * l+1]);

        xt = (pSrc[2 * i] >> 2) - (pSrc[2 * l] >> 2);
        pSrc[2 * i] = (pSrc[2 * i] >> 2) + (pSrc[2 * l] >> 2);
		printf("pSrc[%d] = %d\n",2*i,pSrc[2 * i]);
        yt = (pSrc[2 * i + 1] >> 2) - (pSrc[2 * l + 1] >> 2);
        pSrc[2 * i + 1] = (pSrc[2 * l + 1] >> 2) + (pSrc[2 * i + 1] >> 2);
		printf("pSrc[%d] = %d\n",2*i+1,pSrc[2 * i+1]);
        mult_32x32_keep32_R(p0, xt, cosVal);
        mult_32x32_keep32_R(p1, yt, cosVal);
        multSub_32x32_keep32_R(p0, yt, sinVal);
        multAcc_32x32_keep32_R(p1, xt, sinVal);

        pSrc[2u * l] = p0 << 1;
        pSrc[2u * l + 1u] = p1 << 1;
		printf("pSrc[%d] = %d\n",2*l,pSrc[2 * l]);
		printf("pSrc[%d] = %d\n\n",2*l+1,pSrc[2 * l+1]);
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

		//printf("xccos:%d\n",((q63_t) r1 * co2) >> 32);
		//printf("xcsin:%d\n",((q63_t) s1 * si2) >> 32);
		//printf("xc':%d\n\n",pSrc[2u * i1] >> 1);

      /* yc' = (ya-yb+yc-yd)co2 - (xa-xb+xc-xd)(si2) */
      pSrc[(2u * i1) + 1u] = (((int32_t) (((q63_t) s1 * co2) >> 32)) -
                              ((int32_t) (((q63_t) r1 * si2) >> 32))) << 1u;
//printf("yccos:%d\n",((q63_t) s1 * co2) >> 32);
//printf("ycsin:%d\n",((q63_t) r1 * si2) >> 32);
//printf("yc':%d\n\n",pSrc[(2u * i1) + 1u] >> 1);
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
		//printf("xbcos:%d\n",((q63_t) r1 * co1) >> 32);
		//printf("xbsin:%d\n",((q63_t) s1 * si1) >> 32);
		//printf("xb':%d\n",pSrc[2u * i2] >> 1);

      /* yb' = (ya-xb-yc+xd)co1 - (xa+yb-xc-yd)(si1) */
      pSrc[(2u * i2) + 1u] = (((int32_t) (((q63_t) s1 * co1) >> 32)) -
                              ((int32_t) (((q63_t) r1 * si1) >> 32))) << 1u;
		//printf("ybcos:%d\n",((q63_t) s1 * co1) >> 32);
		//printf("ybsin:%d\n",((q63_t) r1 * si1) >> 32);
		//printf("yb':%d\n\n",pSrc[(2u * i2) + 1u] >> 1);
      /*  index calculation for the coefficients */
      ia3 = 3u * ia1;
      co3 = pCoef[ia3 * 2u];
      si3 = pCoef[(ia3 * 2u) + 1u];
      
      

      /* xd' = (xa-yb-xc+yd)co3 + (ya+xb-yc-xd)(si3) */
      pSrc[2u * i3] = (((int32_t) (((q63_t) r2 * co3) >> 32)) +
                       ((int32_t) (((q63_t) s2 * si3) >> 32))) << 1u;
//printf("xdcos:%d\n",((q63_t) r2 * co3) >> 32);
//printf("xdsin:%d\n",((q63_t) s2 * si3) >> 32);
//printf("xd':%d\n\n",pSrc[2u * i3] >> 1);
      /* yd' = (ya+xb-yc-xd)co3 - (xa-yb-xc+yd)(si3) */
      pSrc[(2u * i3) + 1u] = (((int32_t) (((q63_t) s2 * co3) >> 32)) -
                              ((int32_t) (((q63_t) r2 * si3) >> 32))) << 1u;
//printf("ydcos:%d\n",((q63_t) s2 * co3) >> 32);
//printf("ydsin:%d\n",((q63_t) r2 * si3) >> 32);
//printf("yd':%d\n\n",pSrc[(2u * i3) + 1u] >> 1);
      /*  Twiddle coefficients index modifier */
	  printf("coefficients : wn1[%d], wn2[%d], wn3[%d]\n",ia1, ia2, ia3);
	  printf("wn: %d,%d\t %d,%d\t %d,%d\n", co1,si1,co2,si2,co3,si3);
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
      //printf("Loop %d: %d,%d,\t%d,%d,\t%d,%d,\t%d,%d,\t\n\n",j,xa_out,ya_out,xc_out,yc_out,xb_out,yb_out,xd_out,yd_out);

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
    printf("Entering arm_cfft_radix4by2_q31, fftlen is :%d\n",fftLen);
    for (i = 0; i < n2; i++)
    {
        cosVal = pCoef[2*ia];
        sinVal = pCoef[2*ia + 1];
        printf("cosVal[%d]: %d\tsinVal[%d]: %d\n",2*ia,cosVal,2*ia+1,sinVal);

        ia++;

        l = i + n2;
        //printf("xt = (pSrc[%d] >> 2) - (pSrc[%d] >> 2)\n",i,l);
        //printf("pSrc[%d] = (pSrc[%d] >> 2) + (pSrc[%d] >> 2)\n",i,i,l);
        printf("pSrc[2*i]=%d, pSrc[2*l]=%d\n",pSrc[2 * i],pSrc[2 * l]);
        xt = (pSrc[2 * i] >> 2) - (pSrc[2 * l] >> 2);
        pSrc[2 * i] = (pSrc[2 * i] >> 2) + (pSrc[2 * l] >> 2);
        printf("pSrc[%d] = %d\n",2*i,pSrc[2 * i]);
        //printf("yt is same\n");
        yt = (pSrc[2 * i + 1] >> 2) - (pSrc[2 * l + 1] >> 2);
        pSrc[2 * i + 1] = (pSrc[2 * l + 1] >> 2) + (pSrc[2 * i + 1] >> 2);
        printf("pSrc[%d] = %d\n",2*i+1,pSrc[2 * i+1]);

        //printf("p0 = (xt*cos + L) >> 32\n");
        //printf("p1 = (yt*cos + L) >> 32\n");
		printf("xt:%d, yt:%d\n",xt,yt);
        mult_32x32_keep32_R(p0, xt, cosVal);
        mult_32x32_keep32_R(p1, yt, cosVal);
        //printf("p0=%d, p1=%d\n",p0,p1);

        //printf("p0 = ((p0 << 32) + (yt*sin + L)) >> 32)\n");
        //printf("p1 = ((p1 << 32) - (xt*sin + L)) >> 32)\n");
        multAcc_32x32_keep32_R(p0, yt, sinVal);
        multSub_32x32_keep32_R(p1, xt, sinVal);
        //printf("p0=%d, p1=%d\n",p0,p1);

        //printf("x:pSrc[%d] = p0 << 1\n",l);
        //printf("y:pSrc[%d] = p1 << 1\n\n",l);

        pSrc[2u * l] = p0 << 1;
        pSrc[2u * l + 1u] = p1 << 1;
        printf("pSrc[%d] = %d\n",2*l,pSrc[2 * l]);
        printf("pSrc[%d] = %d\n\n",2*l+1,pSrc[2 * l+1]);
    }

    // first col
    arm_radix4_butterfly_q31( pSrc, n2, (q31_t*)pCoef, 2u);
    // second col
    arm_radix4_butterfly_q31( pSrc + fftLen, n2, (q31_t*)pCoef, 2u);

    printf("POST process\n");
    for (i = 0; i < fftLen >> 1; i++)
    {
        //printf("pSrc[%d~%d]\n",4*i,4*i+3);
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

    printf("Entering bitreverse, bitRevLen is: %d\n",bitRevLen);

    for(i = 0; i< bitRevLen;)
    {
        //printf("a = pBitRevTab[%d] >> 2\n",i);
        //printf("b = pBitRevTab[%d] >> 2\n",i+1);
        a = pBitRevTab[i] >> 2;
        b = pBitRevTab[i+1] >> 2;

        //real
        //printf("Loop: %d\n",i);
        printf("pSrc[%d]:%d <-> pSrc[%d]:%d\n\n",a,pSrc[a],b,pSrc[b]);
        tmp = pSrc[a];
        pSrc[a] = pSrc[b];
        pSrc[b] = tmp;

        //printf("Loop: %d\n",i+1);

        //complex
        printf("pSrc[%d]:%d <-> pSrc[%d]:%d\n\n",a+1,pSrc[a+1],b+1,pSrc[b+1]);
        tmp = pSrc[a+1];
        pSrc[a+1] = pSrc[b+1];
        pSrc[b+1] = tmp;

        i+=2;
    }
    printf("[2]=%d, [3]= %d\n", pSrc[2],pSrc[3]);
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



#define FFT_LEN 128  // FFT 长度
#define REV_LEN 112
#define TWID_LEN 192
#define SRC_BASE 0
#define DEST_BASE 0

const q31_t twiddleCoef_256_q31[384] = {
	(q31_t)0x7FFFFFFF, (q31_t)0x00000000, (q31_t)0x7FF62182,
	(q31_t)0x03242ABF, (q31_t)0x7FD8878D, (q31_t)0x0647D97C,
	(q31_t)0x7FA736B4, (q31_t)0x096A9049, (q31_t)0x7F62368F,
	(q31_t)0x0C8BD35E, (q31_t)0x7F0991C3, (q31_t)0x0FAB272B,
	(q31_t)0x7E9D55FC, (q31_t)0x12C8106E, (q31_t)0x7E1D93E9,
	(q31_t)0x15E21444, (q31_t)0x7D8A5F3F, (q31_t)0x18F8B83C,
	(q31_t)0x7CE3CEB1, (q31_t)0x1C0B826A, (q31_t)0x7C29FBEE,
	(q31_t)0x1F19F97B, (q31_t)0x7B5D039D, (q31_t)0x2223A4C5,
	(q31_t)0x7A7D055B, (q31_t)0x25280C5D, (q31_t)0x798A23B1,
	(q31_t)0x2826B928, (q31_t)0x78848413, (q31_t)0x2B1F34EB,
	(q31_t)0x776C4EDB, (q31_t)0x2E110A62, (q31_t)0x7641AF3C,
	(q31_t)0x30FBC54D, (q31_t)0x7504D345, (q31_t)0x33DEF287,
	(q31_t)0x73B5EBD0, (q31_t)0x36BA2013, (q31_t)0x72552C84,
	(q31_t)0x398CDD32, (q31_t)0x70E2CBC6, (q31_t)0x3C56BA70,
	(q31_t)0x6F5F02B1, (q31_t)0x3F1749B7, (q31_t)0x6DCA0D14,
	(q31_t)0x41CE1E64, (q31_t)0x6C242960, (q31_t)0x447ACD50,
	(q31_t)0x6A6D98A4, (q31_t)0x471CECE6, (q31_t)0x68A69E81,
	(q31_t)0x49B41533, (q31_t)0x66CF811F, (q31_t)0x4C3FDFF3,
	(q31_t)0x64E88926, (q31_t)0x4EBFE8A4, (q31_t)0x62F201AC,
	(q31_t)0x5133CC94, (q31_t)0x60EC3830, (q31_t)0x539B2AEF,
	(q31_t)0x5ED77C89, (q31_t)0x55F5A4D2, (q31_t)0x5CB420DF,
	(q31_t)0x5842DD54, (q31_t)0x5A82799A, (q31_t)0x5A82799A,
	(q31_t)0x5842DD54, (q31_t)0x5CB420DF, (q31_t)0x55F5A4D2,
	(q31_t)0x5ED77C89, (q31_t)0x539B2AEF, (q31_t)0x60EC3830,
	(q31_t)0x5133CC94, (q31_t)0x62F201AC, (q31_t)0x4EBFE8A4,
	(q31_t)0x64E88926, (q31_t)0x4C3FDFF3, (q31_t)0x66CF811F,
	(q31_t)0x49B41533, (q31_t)0x68A69E81, (q31_t)0x471CECE6,
	(q31_t)0x6A6D98A4, (q31_t)0x447ACD50, (q31_t)0x6C242960,
	(q31_t)0x41CE1E64, (q31_t)0x6DCA0D14, (q31_t)0x3F1749B7,
	(q31_t)0x6F5F02B1, (q31_t)0x3C56BA70, (q31_t)0x70E2CBC6,
	(q31_t)0x398CDD32, (q31_t)0x72552C84, (q31_t)0x36BA2013,
	(q31_t)0x73B5EBD0, (q31_t)0x33DEF287, (q31_t)0x7504D345,
	(q31_t)0x30FBC54D, (q31_t)0x7641AF3C, (q31_t)0x2E110A62,
	(q31_t)0x776C4EDB, (q31_t)0x2B1F34EB, (q31_t)0x78848413,
	(q31_t)0x2826B928, (q31_t)0x798A23B1, (q31_t)0x25280C5D,
	(q31_t)0x7A7D055B, (q31_t)0x2223A4C5, (q31_t)0x7B5D039D,
	(q31_t)0x1F19F97B, (q31_t)0x7C29FBEE, (q31_t)0x1C0B826A,
	(q31_t)0x7CE3CEB1, (q31_t)0x18F8B83C, (q31_t)0x7D8A5F3F,
	(q31_t)0x15E21444, (q31_t)0x7E1D93E9, (q31_t)0x12C8106E,
	(q31_t)0x7E9D55FC, (q31_t)0x0FAB272B, (q31_t)0x7F0991C3,
	(q31_t)0x0C8BD35E, (q31_t)0x7F62368F, (q31_t)0x096A9049,
	(q31_t)0x7FA736B4, (q31_t)0x0647D97C, (q31_t)0x7FD8878D,
	(q31_t)0x03242ABF, (q31_t)0x7FF62182, (q31_t)0x00000000,
	(q31_t)0x7FFFFFFF, (q31_t)0xFCDBD541, (q31_t)0x7FF62182,
	(q31_t)0xF9B82683, (q31_t)0x7FD8878D, (q31_t)0xF6956FB6,
	(q31_t)0x7FA736B4, (q31_t)0xF3742CA1, (q31_t)0x7F62368F,
	(q31_t)0xF054D8D4, (q31_t)0x7F0991C3, (q31_t)0xED37EF91,
	(q31_t)0x7E9D55FC, (q31_t)0xEA1DEBBB, (q31_t)0x7E1D93E9,
	(q31_t)0xE70747C3, (q31_t)0x7D8A5F3F, (q31_t)0xE3F47D95,
	(q31_t)0x7CE3CEB1, (q31_t)0xE0E60684, (q31_t)0x7C29FBEE,
	(q31_t)0xDDDC5B3A, (q31_t)0x7B5D039D, (q31_t)0xDAD7F3A2,
	(q31_t)0x7A7D055B, (q31_t)0xD7D946D7, (q31_t)0x798A23B1,
	(q31_t)0xD4E0CB14, (q31_t)0x78848413, (q31_t)0xD1EEF59E,
	(q31_t)0x776C4EDB, (q31_t)0xCF043AB2, (q31_t)0x7641AF3C,
	(q31_t)0xCC210D78, (q31_t)0x7504D345, (q31_t)0xC945DFEC,
	(q31_t)0x73B5EBD0, (q31_t)0xC67322CD, (q31_t)0x72552C84,
	(q31_t)0xC3A9458F, (q31_t)0x70E2CBC6, (q31_t)0xC0E8B648,
	(q31_t)0x6F5F02B1, (q31_t)0xBE31E19B, (q31_t)0x6DCA0D14,
	(q31_t)0xBB8532AF, (q31_t)0x6C242960, (q31_t)0xB8E31319,
	(q31_t)0x6A6D98A4, (q31_t)0xB64BEACC, (q31_t)0x68A69E81,
	(q31_t)0xB3C0200C, (q31_t)0x66CF811F, (q31_t)0xB140175B,
	(q31_t)0x64E88926, (q31_t)0xAECC336B, (q31_t)0x62F201AC,
	(q31_t)0xAC64D510, (q31_t)0x60EC3830, (q31_t)0xAA0A5B2D,
	(q31_t)0x5ED77C89, (q31_t)0xA7BD22AB, (q31_t)0x5CB420DF,
	(q31_t)0xA57D8666, (q31_t)0x5A82799A, (q31_t)0xA34BDF20,
	(q31_t)0x5842DD54, (q31_t)0xA1288376, (q31_t)0x55F5A4D2,
	(q31_t)0x9F13C7D0, (q31_t)0x539B2AEF, (q31_t)0x9D0DFE53,
	(q31_t)0x5133CC94, (q31_t)0x9B1776D9, (q31_t)0x4EBFE8A4,
	(q31_t)0x99307EE0, (q31_t)0x4C3FDFF3, (q31_t)0x9759617E,
	(q31_t)0x49B41533, (q31_t)0x9592675B, (q31_t)0x471CECE6,
	(q31_t)0x93DBD69F, (q31_t)0x447ACD50, (q31_t)0x9235F2EB,
	(q31_t)0x41CE1E64, (q31_t)0x90A0FD4E, (q31_t)0x3F1749B7,
	(q31_t)0x8F1D343A, (q31_t)0x3C56BA70, (q31_t)0x8DAAD37B,
	(q31_t)0x398CDD32, (q31_t)0x8C4A142F, (q31_t)0x36BA2013,
	(q31_t)0x8AFB2CBA, (q31_t)0x33DEF287, (q31_t)0x89BE50C3,
	(q31_t)0x30FBC54D, (q31_t)0x8893B124, (q31_t)0x2E110A62,
	(q31_t)0x877B7BEC, (q31_t)0x2B1F34EB, (q31_t)0x8675DC4E,
	(q31_t)0x2826B928, (q31_t)0x8582FAA4, (q31_t)0x25280C5D,
	(q31_t)0x84A2FC62, (q31_t)0x2223A4C5, (q31_t)0x83D60411,
	(q31_t)0x1F19F97B, (q31_t)0x831C314E, (q31_t)0x1C0B826A,
	(q31_t)0x8275A0C0, (q31_t)0x18F8B83C, (q31_t)0x81E26C16,
	(q31_t)0x15E21444, (q31_t)0x8162AA03, (q31_t)0x12C8106E,
	(q31_t)0x80F66E3C, (q31_t)0x0FAB272B, (q31_t)0x809DC970,
	(q31_t)0x0C8BD35E, (q31_t)0x8058C94C, (q31_t)0x096A9049,
	(q31_t)0x80277872, (q31_t)0x0647D97C, (q31_t)0x8009DE7D,
	(q31_t)0x03242ABF, (q31_t)0x80000000, (q31_t)0x00000000,
	(q31_t)0x8009DE7D, (q31_t)0xFCDBD541, (q31_t)0x80277872,
	(q31_t)0xF9B82683, (q31_t)0x8058C94C, (q31_t)0xF6956FB6,
	(q31_t)0x809DC970, (q31_t)0xF3742CA1, (q31_t)0x80F66E3C,
	(q31_t)0xF054D8D4, (q31_t)0x8162AA03, (q31_t)0xED37EF91,
	(q31_t)0x81E26C16, (q31_t)0xEA1DEBBB, (q31_t)0x8275A0C0,
	(q31_t)0xE70747C3, (q31_t)0x831C314E, (q31_t)0xE3F47D95,
	(q31_t)0x83D60411, (q31_t)0xE0E60684, (q31_t)0x84A2FC62,
	(q31_t)0xDDDC5B3A, (q31_t)0x8582FAA4, (q31_t)0xDAD7F3A2,
	(q31_t)0x8675DC4E, (q31_t)0xD7D946D7, (q31_t)0x877B7BEC,
	(q31_t)0xD4E0CB14, (q31_t)0x8893B124, (q31_t)0xD1EEF59E,
	(q31_t)0x89BE50C3, (q31_t)0xCF043AB2, (q31_t)0x8AFB2CBA,
	(q31_t)0xCC210D78, (q31_t)0x8C4A142F, (q31_t)0xC945DFEC,
	(q31_t)0x8DAAD37B, (q31_t)0xC67322CD, (q31_t)0x8F1D343A,
	(q31_t)0xC3A9458F, (q31_t)0x90A0FD4E, (q31_t)0xC0E8B648,
	(q31_t)0x9235F2EB, (q31_t)0xBE31E19B, (q31_t)0x93DBD69F,
	(q31_t)0xBB8532AF, (q31_t)0x9592675B, (q31_t)0xB8E31319,
	(q31_t)0x9759617E, (q31_t)0xB64BEACC, (q31_t)0x99307EE0,
	(q31_t)0xB3C0200C, (q31_t)0x9B1776D9, (q31_t)0xB140175B,
	(q31_t)0x9D0DFE53, (q31_t)0xAECC336B, (q31_t)0x9F13C7D0,
	(q31_t)0xAC64D510, (q31_t)0xA1288376, (q31_t)0xAA0A5B2D,
	(q31_t)0xA34BDF20, (q31_t)0xA7BD22AB, (q31_t)0xA57D8666,
	(q31_t)0xA57D8666, (q31_t)0xA7BD22AB, (q31_t)0xA34BDF20,
	(q31_t)0xAA0A5B2D, (q31_t)0xA1288376, (q31_t)0xAC64D510,
	(q31_t)0x9F13C7D0, (q31_t)0xAECC336B, (q31_t)0x9D0DFE53,
	(q31_t)0xB140175B, (q31_t)0x9B1776D9, (q31_t)0xB3C0200C,
	(q31_t)0x99307EE0, (q31_t)0xB64BEACC, (q31_t)0x9759617E,
	(q31_t)0xB8E31319, (q31_t)0x9592675B, (q31_t)0xBB8532AF,
	(q31_t)0x93DBD69F, (q31_t)0xBE31E19B, (q31_t)0x9235F2EB,
	(q31_t)0xC0E8B648, (q31_t)0x90A0FD4E, (q31_t)0xC3A9458F,
	(q31_t)0x8F1D343A, (q31_t)0xC67322CD, (q31_t)0x8DAAD37B,
	(q31_t)0xC945DFEC, (q31_t)0x8C4A142F, (q31_t)0xCC210D78,
	(q31_t)0x8AFB2CBA, (q31_t)0xCF043AB2, (q31_t)0x89BE50C3,
	(q31_t)0xD1EEF59E, (q31_t)0x8893B124, (q31_t)0xD4E0CB14,
	(q31_t)0x877B7BEC, (q31_t)0xD7D946D7, (q31_t)0x8675DC4E,
	(q31_t)0xDAD7F3A2, (q31_t)0x8582FAA4, (q31_t)0xDDDC5B3A,
	(q31_t)0x84A2FC62, (q31_t)0xE0E60684, (q31_t)0x83D60411,
	(q31_t)0xE3F47D95, (q31_t)0x831C314E, (q31_t)0xE70747C3,
	(q31_t)0x8275A0C0, (q31_t)0xEA1DEBBB, (q31_t)0x81E26C16,
	(q31_t)0xED37EF91, (q31_t)0x8162AA03, (q31_t)0xF054D8D4,
	(q31_t)0x80F66E3C, (q31_t)0xF3742CA1, (q31_t)0x809DC970,
	(q31_t)0xF6956FB6, (q31_t)0x8058C94C, (q31_t)0xF9B82683,
	(q31_t)0x80277872, (q31_t)0xFCDBD541, (q31_t)0x8009DE7D
};
// **完整的 64 点 Twiddle 因子表（128 个值 = 64 组复数对）**
const q31_t twiddleCoef_128_q31[192] = {
	(q31_t)0x7FFFFFFF, (q31_t)0x00000000, (q31_t)0x7FD8878D,
	(q31_t)0x0647D97C, (q31_t)0x7F62368F, (q31_t)0x0C8BD35E,
	(q31_t)0x7E9D55FC, (q31_t)0x12C8106E, (q31_t)0x7D8A5F3F,
	(q31_t)0x18F8B83C, (q31_t)0x7C29FBEE, (q31_t)0x1F19F97B,
	(q31_t)0x7A7D055B, (q31_t)0x25280C5D, (q31_t)0x78848413,
	(q31_t)0x2B1F34EB, (q31_t)0x7641AF3C, (q31_t)0x30FBC54D,
	(q31_t)0x73B5EBD0, (q31_t)0x36BA2013, (q31_t)0x70E2CBC6,
	(q31_t)0x3C56BA70, (q31_t)0x6DCA0D14, (q31_t)0x41CE1E64,
	(q31_t)0x6A6D98A4, (q31_t)0x471CECE6, (q31_t)0x66CF811F,
	(q31_t)0x4C3FDFF3, (q31_t)0x62F201AC, (q31_t)0x5133CC94,
	(q31_t)0x5ED77C89, (q31_t)0x55F5A4D2, (q31_t)0x5A82799A,
	(q31_t)0x5A82799A, (q31_t)0x55F5A4D2, (q31_t)0x5ED77C89,
	(q31_t)0x5133CC94, (q31_t)0x62F201AC, (q31_t)0x4C3FDFF3,
	(q31_t)0x66CF811F, (q31_t)0x471CECE6, (q31_t)0x6A6D98A4,
	(q31_t)0x41CE1E64, (q31_t)0x6DCA0D14, (q31_t)0x3C56BA70,
	(q31_t)0x70E2CBC6, (q31_t)0x36BA2013, (q31_t)0x73B5EBD0,
	(q31_t)0x30FBC54D, (q31_t)0x7641AF3C, (q31_t)0x2B1F34EB,
	(q31_t)0x78848413, (q31_t)0x25280C5D, (q31_t)0x7A7D055B,
	(q31_t)0x1F19F97B, (q31_t)0x7C29FBEE, (q31_t)0x18F8B83C,
	(q31_t)0x7D8A5F3F, (q31_t)0x12C8106E, (q31_t)0x7E9D55FC,
	(q31_t)0x0C8BD35E, (q31_t)0x7F62368F, (q31_t)0x0647D97C,
	(q31_t)0x7FD8878D, (q31_t)0x00000000, (q31_t)0x7FFFFFFF,
	(q31_t)0xF9B82683, (q31_t)0x7FD8878D, (q31_t)0xF3742CA1,
	(q31_t)0x7F62368F, (q31_t)0xED37EF91, (q31_t)0x7E9D55FC,
	(q31_t)0xE70747C3, (q31_t)0x7D8A5F3F, (q31_t)0xE0E60684,
	(q31_t)0x7C29FBEE, (q31_t)0xDAD7F3A2, (q31_t)0x7A7D055B,
	(q31_t)0xD4E0CB14, (q31_t)0x78848413, (q31_t)0xCF043AB2,
	(q31_t)0x7641AF3C, (q31_t)0xC945DFEC, (q31_t)0x73B5EBD0,
	(q31_t)0xC3A9458F, (q31_t)0x70E2CBC6, (q31_t)0xBE31E19B,
	(q31_t)0x6DCA0D14, (q31_t)0xB8E31319, (q31_t)0x6A6D98A4,
	(q31_t)0xB3C0200C, (q31_t)0x66CF811F, (q31_t)0xAECC336B,
	(q31_t)0x62F201AC, (q31_t)0xAA0A5B2D, (q31_t)0x5ED77C89,
	(q31_t)0xA57D8666, (q31_t)0x5A82799A, (q31_t)0xA1288376,
	(q31_t)0x55F5A4D2, (q31_t)0x9D0DFE53, (q31_t)0x5133CC94,
	(q31_t)0x99307EE0, (q31_t)0x4C3FDFF3, (q31_t)0x9592675B,
	(q31_t)0x471CECE6, (q31_t)0x9235F2EB, (q31_t)0x41CE1E64,
	(q31_t)0x8F1D343A, (q31_t)0x3C56BA70, (q31_t)0x8C4A142F,
	(q31_t)0x36BA2013, (q31_t)0x89BE50C3, (q31_t)0x30FBC54D,
	(q31_t)0x877B7BEC, (q31_t)0x2B1F34EB, (q31_t)0x8582FAA4,
	(q31_t)0x25280C5D, (q31_t)0x83D60411, (q31_t)0x1F19F97B,
	(q31_t)0x8275A0C0, (q31_t)0x18F8B83C, (q31_t)0x8162AA03,
	(q31_t)0x12C8106E, (q31_t)0x809DC970, (q31_t)0x0C8BD35E,
	(q31_t)0x80277872, (q31_t)0x0647D97C, (q31_t)0x80000000,
	(q31_t)0x00000000, (q31_t)0x80277872, (q31_t)0xF9B82683,
	(q31_t)0x809DC970, (q31_t)0xF3742CA1, (q31_t)0x8162AA03,
	(q31_t)0xED37EF91, (q31_t)0x8275A0C0, (q31_t)0xE70747C3,
	(q31_t)0x83D60411, (q31_t)0xE0E60684, (q31_t)0x8582FAA4,
	(q31_t)0xDAD7F3A2, (q31_t)0x877B7BEC, (q31_t)0xD4E0CB14,
	(q31_t)0x89BE50C3, (q31_t)0xCF043AB2, (q31_t)0x8C4A142F,
	(q31_t)0xC945DFEC, (q31_t)0x8F1D343A, (q31_t)0xC3A9458F,
	(q31_t)0x9235F2EB, (q31_t)0xBE31E19B, (q31_t)0x9592675B,
	(q31_t)0xB8E31319, (q31_t)0x99307EE0, (q31_t)0xB3C0200C,
	(q31_t)0x9D0DFE53, (q31_t)0xAECC336B, (q31_t)0xA1288376,
	(q31_t)0xAA0A5B2D, (q31_t)0xA57D8666, (q31_t)0xA57D8666,
	(q31_t)0xAA0A5B2D, (q31_t)0xA1288376, (q31_t)0xAECC336B,
	(q31_t)0x9D0DFE53, (q31_t)0xB3C0200C, (q31_t)0x99307EE0,
	(q31_t)0xB8E31319, (q31_t)0x9592675B, (q31_t)0xBE31E19B,
	(q31_t)0x9235F2EB, (q31_t)0xC3A9458F, (q31_t)0x8F1D343A,
	(q31_t)0xC945DFEC, (q31_t)0x8C4A142F, (q31_t)0xCF043AB2,
	(q31_t)0x89BE50C3, (q31_t)0xD4E0CB14, (q31_t)0x877B7BEC,
	(q31_t)0xDAD7F3A2, (q31_t)0x8582FAA4, (q31_t)0xE0E60684,
	(q31_t)0x83D60411, (q31_t)0xE70747C3, (q31_t)0x8275A0C0,
	(q31_t)0xED37EF91, (q31_t)0x8162AA03, (q31_t)0xF3742CA1,
	(q31_t)0x809DC970, (q31_t)0xF9B82683, (q31_t)0x80277872
};

const q31_t twiddleCoef_2048_q31[3072] = {
	(q31_t)0x7FFFFFFF, (q31_t)0x00000000, (q31_t)0x7FFFD885,
	(q31_t)0x006487E3, (q31_t)0x7FFF6216, (q31_t)0x00C90F88,
	(q31_t)0x7FFE9CB2, (q31_t)0x012D96B0, (q31_t)0x7FFD885A,
	(q31_t)0x01921D1F, (q31_t)0x7FFC250F, (q31_t)0x01F6A296,
	(q31_t)0x7FFA72D1, (q31_t)0x025B26D7, (q31_t)0x7FF871A1,
	(q31_t)0x02BFA9A4, (q31_t)0x7FF62182, (q31_t)0x03242ABF,
	(q31_t)0x7FF38273, (q31_t)0x0388A9E9, (q31_t)0x7FF09477,
	(q31_t)0x03ED26E6, (q31_t)0x7FED5790, (q31_t)0x0451A176,
	(q31_t)0x7FE9CBC0, (q31_t)0x04B6195D, (q31_t)0x7FE5F108,
	(q31_t)0x051A8E5C, (q31_t)0x7FE1C76B, (q31_t)0x057F0034,
	(q31_t)0x7FDD4EEC, (q31_t)0x05E36EA9, (q31_t)0x7FD8878D,
	(q31_t)0x0647D97C, (q31_t)0x7FD37152, (q31_t)0x06AC406F,
	(q31_t)0x7FCE0C3E, (q31_t)0x0710A344, (q31_t)0x7FC85853,
	(q31_t)0x077501BE, (q31_t)0x7FC25596, (q31_t)0x07D95B9E,
	(q31_t)0x7FBC040A, (q31_t)0x083DB0A7, (q31_t)0x7FB563B2,
	(q31_t)0x08A2009A, (q31_t)0x7FAE7494, (q31_t)0x09064B3A,
	(q31_t)0x7FA736B4, (q31_t)0x096A9049, (q31_t)0x7F9FAA15,
	(q31_t)0x09CECF89, (q31_t)0x7F97CEBC, (q31_t)0x0A3308BC,
	(q31_t)0x7F8FA4AF, (q31_t)0x0A973BA5, (q31_t)0x7F872BF3,
	(q31_t)0x0AFB6805, (q31_t)0x7F7E648B, (q31_t)0x0B5F8D9F,
	(q31_t)0x7F754E7F, (q31_t)0x0BC3AC35, (q31_t)0x7F6BE9D4,
	(q31_t)0x0C27C389, (q31_t)0x7F62368F, (q31_t)0x0C8BD35E,
	(q31_t)0x7F5834B6, (q31_t)0x0CEFDB75, (q31_t)0x7F4DE450,
	(q31_t)0x0D53DB92, (q31_t)0x7F434563, (q31_t)0x0DB7D376,
	(q31_t)0x7F3857F5, (q31_t)0x0E1BC2E3, (q31_t)0x7F2D1C0E,
	(q31_t)0x0E7FA99D, (q31_t)0x7F2191B4, (q31_t)0x0EE38765,
	(q31_t)0x7F15B8EE, (q31_t)0x0F475BFE, (q31_t)0x7F0991C3,
	(q31_t)0x0FAB272B, (q31_t)0x7EFD1C3C, (q31_t)0x100EE8AD,
	(q31_t)0x7EF0585F, (q31_t)0x1072A047, (q31_t)0x7EE34635,
	(q31_t)0x10D64DBC, (q31_t)0x7ED5E5C6, (q31_t)0x1139F0CE,
	(q31_t)0x7EC8371A, (q31_t)0x119D8940, (q31_t)0x7EBA3A39,
	(q31_t)0x120116D4, (q31_t)0x7EABEF2C, (q31_t)0x1264994E,
	(q31_t)0x7E9D55FC, (q31_t)0x12C8106E, (q31_t)0x7E8E6EB1,
	(q31_t)0x132B7BF9, (q31_t)0x7E7F3956, (q31_t)0x138EDBB0,
	(q31_t)0x7E6FB5F3, (q31_t)0x13F22F57, (q31_t)0x7E5FE493,
	(q31_t)0x145576B1, (q31_t)0x7E4FC53E, (q31_t)0x14B8B17F,
	(q31_t)0x7E3F57FE, (q31_t)0x151BDF85, (q31_t)0x7E2E9CDF,
	(q31_t)0x157F0086, (q31_t)0x7E1D93E9, (q31_t)0x15E21444,
	(q31_t)0x7E0C3D29, (q31_t)0x16451A83, (q31_t)0x7DFA98A7,
	(q31_t)0x16A81305, (q31_t)0x7DE8A670, (q31_t)0x170AFD8D,
	(q31_t)0x7DD6668E, (q31_t)0x176DD9DE, (q31_t)0x7DC3D90D,
	(q31_t)0x17D0A7BB, (q31_t)0x7DB0FDF7, (q31_t)0x183366E8,
	(q31_t)0x7D9DD55A, (q31_t)0x18961727, (q31_t)0x7D8A5F3F,
	(q31_t)0x18F8B83C, (q31_t)0x7D769BB5, (q31_t)0x195B49E9,
	(q31_t)0x7D628AC5, (q31_t)0x19BDCBF2, (q31_t)0x7D4E2C7E,
	(q31_t)0x1A203E1B, (q31_t)0x7D3980EC, (q31_t)0x1A82A025,
	(q31_t)0x7D24881A, (q31_t)0x1AE4F1D6, (q31_t)0x7D0F4218,
	(q31_t)0x1B4732EF, (q31_t)0x7CF9AEF0, (q31_t)0x1BA96334,
	(q31_t)0x7CE3CEB1, (q31_t)0x1C0B826A, (q31_t)0x7CCDA168,
	(q31_t)0x1C6D9053, (q31_t)0x7CB72724, (q31_t)0x1CCF8CB3,
	(q31_t)0x7CA05FF1, (q31_t)0x1D31774D, (q31_t)0x7C894BDD,
	(q31_t)0x1D934FE5, (q31_t)0x7C71EAF8, (q31_t)0x1DF5163F,
	(q31_t)0x7C5A3D4F, (q31_t)0x1E56CA1E, (q31_t)0x7C4242F2,
	(q31_t)0x1EB86B46, (q31_t)0x7C29FBEE, (q31_t)0x1F19F97B,
	(q31_t)0x7C116853, (q31_t)0x1F7B7480, (q31_t)0x7BF88830,
	(q31_t)0x1FDCDC1A, (q31_t)0x7BDF5B94, (q31_t)0x203E300D,
	(q31_t)0x7BC5E28F, (q31_t)0x209F701C, (q31_t)0x7BAC1D31,
	(q31_t)0x21009C0B, (q31_t)0x7B920B89, (q31_t)0x2161B39F,
	(q31_t)0x7B77ADA8, (q31_t)0x21C2B69C, (q31_t)0x7B5D039D,
	(q31_t)0x2223A4C5, (q31_t)0x7B420D7A, (q31_t)0x22847DDF,
	(q31_t)0x7B26CB4F, (q31_t)0x22E541AE, (q31_t)0x7B0B3D2C,
	(q31_t)0x2345EFF7, (q31_t)0x7AEF6323, (q31_t)0x23A6887E,
	(q31_t)0x7AD33D45, (q31_t)0x24070B07, (q31_t)0x7AB6CBA3,
	(q31_t)0x24677757, (q31_t)0x7A9A0E4F, (q31_t)0x24C7CD32,
	(q31_t)0x7A7D055B, (q31_t)0x25280C5D, (q31_t)0x7A5FB0D8,
	(q31_t)0x2588349D, (q31_t)0x7A4210D8, (q31_t)0x25E845B5,
	(q31_t)0x7A24256E, (q31_t)0x26483F6C, (q31_t)0x7A05EEAD,
	(q31_t)0x26A82185, (q31_t)0x79E76CA6, (q31_t)0x2707EBC6,
	(q31_t)0x79C89F6D, (q31_t)0x27679DF4, (q31_t)0x79A98715,
	(q31_t)0x27C737D2, (q31_t)0x798A23B1, (q31_t)0x2826B928,
	(q31_t)0x796A7554, (q31_t)0x288621B9, (q31_t)0x794A7C11,
	(q31_t)0x28E5714A, (q31_t)0x792A37FE, (q31_t)0x2944A7A2,
	(q31_t)0x7909A92C, (q31_t)0x29A3C484, (q31_t)0x78E8CFB1,
	(q31_t)0x2A02C7B8, (q31_t)0x78C7ABA1, (q31_t)0x2A61B101,
	(q31_t)0x78A63D10, (q31_t)0x2AC08025, (q31_t)0x78848413,
	(q31_t)0x2B1F34EB, (q31_t)0x786280BF, (q31_t)0x2B7DCF17,
	(q31_t)0x78403328, (q31_t)0x2BDC4E6F, (q31_t)0x781D9B64,
	(q31_t)0x2C3AB2B9, (q31_t)0x77FAB988, (q31_t)0x2C98FBBA,
	(q31_t)0x77D78DAA, (q31_t)0x2CF72939, (q31_t)0x77B417DF,
	(q31_t)0x2D553AFB, (q31_t)0x7790583D, (q31_t)0x2DB330C7,
	(q31_t)0x776C4EDB, (q31_t)0x2E110A62, (q31_t)0x7747FBCE,
	(q31_t)0x2E6EC792, (q31_t)0x77235F2D, (q31_t)0x2ECC681E,
	(q31_t)0x76FE790E, (q31_t)0x2F29EBCC, (q31_t)0x76D94988,
	(q31_t)0x2F875262, (q31_t)0x76B3D0B3, (q31_t)0x2FE49BA6,
	(q31_t)0x768E0EA5, (q31_t)0x3041C760, (q31_t)0x76680376,
	(q31_t)0x309ED555, (q31_t)0x7641AF3C, (q31_t)0x30FBC54D,
	(q31_t)0x761B1211, (q31_t)0x3158970D, (q31_t)0x75F42C0A,
	(q31_t)0x31B54A5D, (q31_t)0x75CCFD42, (q31_t)0x3211DF03,
	(q31_t)0x75A585CF, (q31_t)0x326E54C7, (q31_t)0x757DC5CA,
	(q31_t)0x32CAAB6F, (q31_t)0x7555BD4B, (q31_t)0x3326E2C2,
	(q31_t)0x752D6C6C, (q31_t)0x3382FA88, (q31_t)0x7504D345,
	(q31_t)0x33DEF287, (q31_t)0x74DBF1EF, (q31_t)0x343ACA87,
	(q31_t)0x74B2C883, (q31_t)0x3496824F, (q31_t)0x7489571B,
	(q31_t)0x34F219A7, (q31_t)0x745F9DD1, (q31_t)0x354D9056,
	(q31_t)0x74359CBD, (q31_t)0x35A8E624, (q31_t)0x740B53FA,
	(q31_t)0x36041AD9, (q31_t)0x73E0C3A3, (q31_t)0x365F2E3B,
	(q31_t)0x73B5EBD0, (q31_t)0x36BA2013, (q31_t)0x738ACC9E,
	(q31_t)0x3714F02A, (q31_t)0x735F6626, (q31_t)0x376F9E46,
	(q31_t)0x7333B883, (q31_t)0x37CA2A30, (q31_t)0x7307C3D0,
	(q31_t)0x382493B0, (q31_t)0x72DB8828, (q31_t)0x387EDA8E,
	(q31_t)0x72AF05A6, (q31_t)0x38D8FE93, (q31_t)0x72823C66,
	(q31_t)0x3932FF87, (q31_t)0x72552C84, (q31_t)0x398CDD32,
	(q31_t)0x7227D61C, (q31_t)0x39E6975D, (q31_t)0x71FA3948,
	(q31_t)0x3A402DD1, (q31_t)0x71CC5626, (q31_t)0x3A99A057,
	(q31_t)0x719E2CD2, (q31_t)0x3AF2EEB7, (q31_t)0x716FBD68,
	(q31_t)0x3B4C18BA, (q31_t)0x71410804, (q31_t)0x3BA51E29,
	(q31_t)0x71120CC5, (q31_t)0x3BFDFECD, (q31_t)0x70E2CBC6,
	(q31_t)0x3C56BA70, (q31_t)0x70B34524, (q31_t)0x3CAF50DA,
	(q31_t)0x708378FE, (q31_t)0x3D07C1D5, (q31_t)0x70536771,
	(q31_t)0x3D600D2B, (q31_t)0x70231099, (q31_t)0x3DB832A5,
	(q31_t)0x6FF27496, (q31_t)0x3E10320D, (q31_t)0x6FC19385,
	(q31_t)0x3E680B2C, (q31_t)0x6F906D84, (q31_t)0x3EBFBDCC,
	(q31_t)0x6F5F02B1, (q31_t)0x3F1749B7, (q31_t)0x6F2D532C,
	(q31_t)0x3F6EAEB8, (q31_t)0x6EFB5F12, (q31_t)0x3FC5EC97,
	(q31_t)0x6EC92682, (q31_t)0x401D0320, (q31_t)0x6E96A99C,
	(q31_t)0x4073F21D, (q31_t)0x6E63E87F, (q31_t)0x40CAB957,
	(q31_t)0x6E30E349, (q31_t)0x4121589A, (q31_t)0x6DFD9A1B,
	(q31_t)0x4177CFB0, (q31_t)0x6DCA0D14, (q31_t)0x41CE1E64,
	(q31_t)0x6D963C54, (q31_t)0x42244480, (q31_t)0x6D6227FA,
	(q31_t)0x427A41D0, (q31_t)0x6D2DD027, (q31_t)0x42D0161E,
	(q31_t)0x6CF934FB, (q31_t)0x4325C135, (q31_t)0x6CC45697,
	(q31_t)0x437B42E1, (q31_t)0x6C8F351C, (q31_t)0x43D09AEC,
	(q31_t)0x6C59D0A9, (q31_t)0x4425C923, (q31_t)0x6C242960,
	(q31_t)0x447ACD50, (q31_t)0x6BEE3F62, (q31_t)0x44CFA73F,
	(q31_t)0x6BB812D0, (q31_t)0x452456BC, (q31_t)0x6B81A3CD,
	(q31_t)0x4578DB93, (q31_t)0x6B4AF278, (q31_t)0x45CD358F,
	(q31_t)0x6B13FEF5, (q31_t)0x4621647C, (q31_t)0x6ADCC964,
	(q31_t)0x46756827, (q31_t)0x6AA551E8, (q31_t)0x46C9405C,
	(q31_t)0x6A6D98A4, (q31_t)0x471CECE6, (q31_t)0x6A359DB9,
	(q31_t)0x47706D93, (q31_t)0x69FD614A, (q31_t)0x47C3C22E,
	(q31_t)0x69C4E37A, (q31_t)0x4816EA85, (q31_t)0x698C246C,
	(q31_t)0x4869E664, (q31_t)0x69532442, (q31_t)0x48BCB598,
	(q31_t)0x6919E320, (q31_t)0x490F57EE, (q31_t)0x68E06129,
	(q31_t)0x4961CD32, (q31_t)0x68A69E81, (q31_t)0x49B41533,
	(q31_t)0x686C9B4B, (q31_t)0x4A062FBD, (q31_t)0x683257AA,
	(q31_t)0x4A581C9D, (q31_t)0x67F7D3C4, (q31_t)0x4AA9DBA1,
	(q31_t)0x67BD0FBC, (q31_t)0x4AFB6C97, (q31_t)0x67820BB6,
	(q31_t)0x4B4CCF4D, (q31_t)0x6746C7D7, (q31_t)0x4B9E038F,
	(q31_t)0x670B4443, (q31_t)0x4BEF092D, (q31_t)0x66CF811F,
	(q31_t)0x4C3FDFF3, (q31_t)0x66937E90, (q31_t)0x4C9087B1,
	(q31_t)0x66573CBB, (q31_t)0x4CE10034, (q31_t)0x661ABBC5,
	(q31_t)0x4D31494B, (q31_t)0x65DDFBD3, (q31_t)0x4D8162C4,
	(q31_t)0x65A0FD0B, (q31_t)0x4DD14C6E, (q31_t)0x6563BF92,
	(q31_t)0x4E210617, (q31_t)0x6526438E, (q31_t)0x4E708F8F,
	(q31_t)0x64E88926, (q31_t)0x4EBFE8A4, (q31_t)0x64AA907F,
	(q31_t)0x4F0F1126, (q31_t)0x646C59BF, (q31_t)0x4F5E08E3,
	(q31_t)0x642DE50D, (q31_t)0x4FACCFAB, (q31_t)0x63EF328F,
	(q31_t)0x4FFB654D, (q31_t)0x63B0426D, (q31_t)0x5049C999,
	(q31_t)0x637114CC, (q31_t)0x5097FC5E, (q31_t)0x6331A9D4,
	(q31_t)0x50E5FD6C, (q31_t)0x62F201AC, (q31_t)0x5133CC94,
	(q31_t)0x62B21C7B, (q31_t)0x518169A4, (q31_t)0x6271FA69,
	(q31_t)0x51CED46E, (q31_t)0x62319B9D, (q31_t)0x521C0CC1,
	(q31_t)0x61F1003E, (q31_t)0x5269126E, (q31_t)0x61B02876,
	(q31_t)0x52B5E545, (q31_t)0x616F146B, (q31_t)0x53028517,
	(q31_t)0x612DC446, (q31_t)0x534EF1B5, (q31_t)0x60EC3830,
	(q31_t)0x539B2AEF, (q31_t)0x60AA704F, (q31_t)0x53E73097,
	(q31_t)0x60686CCE, (q31_t)0x5433027D, (q31_t)0x60262DD5,
	(q31_t)0x547EA073, (q31_t)0x5FE3B38D, (q31_t)0x54CA0A4A,
	(q31_t)0x5FA0FE1E, (q31_t)0x55153FD4, (q31_t)0x5F5E0DB3,
	(q31_t)0x556040E2, (q31_t)0x5F1AE273, (q31_t)0x55AB0D46,
	(q31_t)0x5ED77C89, (q31_t)0x55F5A4D2, (q31_t)0x5E93DC1F,
	(q31_t)0x56400757, (q31_t)0x5E50015D, (q31_t)0x568A34A9,
	(q31_t)0x5E0BEC6E, (q31_t)0x56D42C99, (q31_t)0x5DC79D7C,
	(q31_t)0x571DEEF9, (q31_t)0x5D8314B0, (q31_t)0x57677B9D,
	(q31_t)0x5D3E5236, (q31_t)0x57B0D256, (q31_t)0x5CF95638,
	(q31_t)0x57F9F2F7, (q31_t)0x5CB420DF, (q31_t)0x5842DD54,
	(q31_t)0x5C6EB258, (q31_t)0x588B913F, (q31_t)0x5C290ACC,
	(q31_t)0x58D40E8C, (q31_t)0x5BE32A67, (q31_t)0x591C550E,
	(q31_t)0x5B9D1153, (q31_t)0x59646497, (q31_t)0x5B56BFBD,
	(q31_t)0x59AC3CFD, (q31_t)0x5B1035CF, (q31_t)0x59F3DE12,
	(q31_t)0x5AC973B4, (q31_t)0x5A3B47AA, (q31_t)0x5A82799A,
	(q31_t)0x5A82799A, (q31_t)0x5A3B47AA, (q31_t)0x5AC973B4,
	(q31_t)0x59F3DE12, (q31_t)0x5B1035CF, (q31_t)0x59AC3CFD,
	(q31_t)0x5B56BFBD, (q31_t)0x59646497, (q31_t)0x5B9D1153,
	(q31_t)0x591C550E, (q31_t)0x5BE32A67, (q31_t)0x58D40E8C,
	(q31_t)0x5C290ACC, (q31_t)0x588B913F, (q31_t)0x5C6EB258,
	(q31_t)0x5842DD54, (q31_t)0x5CB420DF, (q31_t)0x57F9F2F7,
	(q31_t)0x5CF95638, (q31_t)0x57B0D256, (q31_t)0x5D3E5236,
	(q31_t)0x57677B9D, (q31_t)0x5D8314B0, (q31_t)0x571DEEF9,
	(q31_t)0x5DC79D7C, (q31_t)0x56D42C99, (q31_t)0x5E0BEC6E,
	(q31_t)0x568A34A9, (q31_t)0x5E50015D, (q31_t)0x56400757,
	(q31_t)0x5E93DC1F, (q31_t)0x55F5A4D2, (q31_t)0x5ED77C89,
	(q31_t)0x55AB0D46, (q31_t)0x5F1AE273, (q31_t)0x556040E2,
	(q31_t)0x5F5E0DB3, (q31_t)0x55153FD4, (q31_t)0x5FA0FE1E,
	(q31_t)0x54CA0A4A, (q31_t)0x5FE3B38D, (q31_t)0x547EA073,
	(q31_t)0x60262DD5, (q31_t)0x5433027D, (q31_t)0x60686CCE,
	(q31_t)0x53E73097, (q31_t)0x60AA704F, (q31_t)0x539B2AEF,
	(q31_t)0x60EC3830, (q31_t)0x534EF1B5, (q31_t)0x612DC446,
	(q31_t)0x53028517, (q31_t)0x616F146B, (q31_t)0x52B5E545,
	(q31_t)0x61B02876, (q31_t)0x5269126E, (q31_t)0x61F1003E,
	(q31_t)0x521C0CC1, (q31_t)0x62319B9D, (q31_t)0x51CED46E,
	(q31_t)0x6271FA69, (q31_t)0x518169A4, (q31_t)0x62B21C7B,
	(q31_t)0x5133CC94, (q31_t)0x62F201AC, (q31_t)0x50E5FD6C,
	(q31_t)0x6331A9D4, (q31_t)0x5097FC5E, (q31_t)0x637114CC,
	(q31_t)0x5049C999, (q31_t)0x63B0426D, (q31_t)0x4FFB654D,
	(q31_t)0x63EF328F, (q31_t)0x4FACCFAB, (q31_t)0x642DE50D,
	(q31_t)0x4F5E08E3, (q31_t)0x646C59BF, (q31_t)0x4F0F1126,
	(q31_t)0x64AA907F, (q31_t)0x4EBFE8A4, (q31_t)0x64E88926,
	(q31_t)0x4E708F8F, (q31_t)0x6526438E, (q31_t)0x4E210617,
	(q31_t)0x6563BF92, (q31_t)0x4DD14C6E, (q31_t)0x65A0FD0B,
	(q31_t)0x4D8162C4, (q31_t)0x65DDFBD3, (q31_t)0x4D31494B,
	(q31_t)0x661ABBC5, (q31_t)0x4CE10034, (q31_t)0x66573CBB,
	(q31_t)0x4C9087B1, (q31_t)0x66937E90, (q31_t)0x4C3FDFF3,
	(q31_t)0x66CF811F, (q31_t)0x4BEF092D, (q31_t)0x670B4443,
	(q31_t)0x4B9E038F, (q31_t)0x6746C7D7, (q31_t)0x4B4CCF4D,
	(q31_t)0x67820BB6, (q31_t)0x4AFB6C97, (q31_t)0x67BD0FBC,
	(q31_t)0x4AA9DBA1, (q31_t)0x67F7D3C4, (q31_t)0x4A581C9D,
	(q31_t)0x683257AA, (q31_t)0x4A062FBD, (q31_t)0x686C9B4B,
	(q31_t)0x49B41533, (q31_t)0x68A69E81, (q31_t)0x4961CD32,
	(q31_t)0x68E06129, (q31_t)0x490F57EE, (q31_t)0x6919E320,
	(q31_t)0x48BCB598, (q31_t)0x69532442, (q31_t)0x4869E664,
	(q31_t)0x698C246C, (q31_t)0x4816EA85, (q31_t)0x69C4E37A,
	(q31_t)0x47C3C22E, (q31_t)0x69FD614A, (q31_t)0x47706D93,
	(q31_t)0x6A359DB9, (q31_t)0x471CECE6, (q31_t)0x6A6D98A4,
	(q31_t)0x46C9405C, (q31_t)0x6AA551E8, (q31_t)0x46756827,
	(q31_t)0x6ADCC964, (q31_t)0x4621647C, (q31_t)0x6B13FEF5,
	(q31_t)0x45CD358F, (q31_t)0x6B4AF278, (q31_t)0x4578DB93,
	(q31_t)0x6B81A3CD, (q31_t)0x452456BC, (q31_t)0x6BB812D0,
	(q31_t)0x44CFA73F, (q31_t)0x6BEE3F62, (q31_t)0x447ACD50,
	(q31_t)0x6C242960, (q31_t)0x4425C923, (q31_t)0x6C59D0A9,
	(q31_t)0x43D09AEC, (q31_t)0x6C8F351C, (q31_t)0x437B42E1,
	(q31_t)0x6CC45697, (q31_t)0x4325C135, (q31_t)0x6CF934FB,
	(q31_t)0x42D0161E, (q31_t)0x6D2DD027, (q31_t)0x427A41D0,
	(q31_t)0x6D6227FA, (q31_t)0x42244480, (q31_t)0x6D963C54,
	(q31_t)0x41CE1E64, (q31_t)0x6DCA0D14, (q31_t)0x4177CFB0,
	(q31_t)0x6DFD9A1B, (q31_t)0x4121589A, (q31_t)0x6E30E349,
	(q31_t)0x40CAB957, (q31_t)0x6E63E87F, (q31_t)0x4073F21D,
	(q31_t)0x6E96A99C, (q31_t)0x401D0320, (q31_t)0x6EC92682,
	(q31_t)0x3FC5EC97, (q31_t)0x6EFB5F12, (q31_t)0x3F6EAEB8,
	(q31_t)0x6F2D532C, (q31_t)0x3F1749B7, (q31_t)0x6F5F02B1,
	(q31_t)0x3EBFBDCC, (q31_t)0x6F906D84, (q31_t)0x3E680B2C,
	(q31_t)0x6FC19385, (q31_t)0x3E10320D, (q31_t)0x6FF27496,
	(q31_t)0x3DB832A5, (q31_t)0x70231099, (q31_t)0x3D600D2B,
	(q31_t)0x70536771, (q31_t)0x3D07C1D5, (q31_t)0x708378FE,
	(q31_t)0x3CAF50DA, (q31_t)0x70B34524, (q31_t)0x3C56BA70,
	(q31_t)0x70E2CBC6, (q31_t)0x3BFDFECD, (q31_t)0x71120CC5,
	(q31_t)0x3BA51E29, (q31_t)0x71410804, (q31_t)0x3B4C18BA,
	(q31_t)0x716FBD68, (q31_t)0x3AF2EEB7, (q31_t)0x719E2CD2,
	(q31_t)0x3A99A057, (q31_t)0x71CC5626, (q31_t)0x3A402DD1,
	(q31_t)0x71FA3948, (q31_t)0x39E6975D, (q31_t)0x7227D61C,
	(q31_t)0x398CDD32, (q31_t)0x72552C84, (q31_t)0x3932FF87,
	(q31_t)0x72823C66, (q31_t)0x38D8FE93, (q31_t)0x72AF05A6,
	(q31_t)0x387EDA8E, (q31_t)0x72DB8828, (q31_t)0x382493B0,
	(q31_t)0x7307C3D0, (q31_t)0x37CA2A30, (q31_t)0x7333B883,
	(q31_t)0x376F9E46, (q31_t)0x735F6626, (q31_t)0x3714F02A,
	(q31_t)0x738ACC9E, (q31_t)0x36BA2013, (q31_t)0x73B5EBD0,
	(q31_t)0x365F2E3B, (q31_t)0x73E0C3A3, (q31_t)0x36041AD9,
	(q31_t)0x740B53FA, (q31_t)0x35A8E624, (q31_t)0x74359CBD,
	(q31_t)0x354D9056, (q31_t)0x745F9DD1, (q31_t)0x34F219A7,
	(q31_t)0x7489571B, (q31_t)0x3496824F, (q31_t)0x74B2C883,
	(q31_t)0x343ACA87, (q31_t)0x74DBF1EF, (q31_t)0x33DEF287,
	(q31_t)0x7504D345, (q31_t)0x3382FA88, (q31_t)0x752D6C6C,
	(q31_t)0x3326E2C2, (q31_t)0x7555BD4B, (q31_t)0x32CAAB6F,
	(q31_t)0x757DC5CA, (q31_t)0x326E54C7, (q31_t)0x75A585CF,
	(q31_t)0x3211DF03, (q31_t)0x75CCFD42, (q31_t)0x31B54A5D,
	(q31_t)0x75F42C0A, (q31_t)0x3158970D, (q31_t)0x761B1211,
	(q31_t)0x30FBC54D, (q31_t)0x7641AF3C, (q31_t)0x309ED555,
	(q31_t)0x76680376, (q31_t)0x3041C760, (q31_t)0x768E0EA5,
	(q31_t)0x2FE49BA6, (q31_t)0x76B3D0B3, (q31_t)0x2F875262,
	(q31_t)0x76D94988, (q31_t)0x2F29EBCC, (q31_t)0x76FE790E,
	(q31_t)0x2ECC681E, (q31_t)0x77235F2D, (q31_t)0x2E6EC792,
	(q31_t)0x7747FBCE, (q31_t)0x2E110A62, (q31_t)0x776C4EDB,
	(q31_t)0x2DB330C7, (q31_t)0x7790583D, (q31_t)0x2D553AFB,
	(q31_t)0x77B417DF, (q31_t)0x2CF72939, (q31_t)0x77D78DAA,
	(q31_t)0x2C98FBBA, (q31_t)0x77FAB988, (q31_t)0x2C3AB2B9,
	(q31_t)0x781D9B64, (q31_t)0x2BDC4E6F, (q31_t)0x78403328,
	(q31_t)0x2B7DCF17, (q31_t)0x786280BF, (q31_t)0x2B1F34EB,
	(q31_t)0x78848413, (q31_t)0x2AC08025, (q31_t)0x78A63D10,
	(q31_t)0x2A61B101, (q31_t)0x78C7ABA1, (q31_t)0x2A02C7B8,
	(q31_t)0x78E8CFB1, (q31_t)0x29A3C484, (q31_t)0x7909A92C,
	(q31_t)0x2944A7A2, (q31_t)0x792A37FE, (q31_t)0x28E5714A,
	(q31_t)0x794A7C11, (q31_t)0x288621B9, (q31_t)0x796A7554,
	(q31_t)0x2826B928, (q31_t)0x798A23B1, (q31_t)0x27C737D2,
	(q31_t)0x79A98715, (q31_t)0x27679DF4, (q31_t)0x79C89F6D,
	(q31_t)0x2707EBC6, (q31_t)0x79E76CA6, (q31_t)0x26A82185,
	(q31_t)0x7A05EEAD, (q31_t)0x26483F6C, (q31_t)0x7A24256E,
	(q31_t)0x25E845B5, (q31_t)0x7A4210D8, (q31_t)0x2588349D,
	(q31_t)0x7A5FB0D8, (q31_t)0x25280C5D, (q31_t)0x7A7D055B,
	(q31_t)0x24C7CD32, (q31_t)0x7A9A0E4F, (q31_t)0x24677757,
	(q31_t)0x7AB6CBA3, (q31_t)0x24070B07, (q31_t)0x7AD33D45,
	(q31_t)0x23A6887E, (q31_t)0x7AEF6323, (q31_t)0x2345EFF7,
	(q31_t)0x7B0B3D2C, (q31_t)0x22E541AE, (q31_t)0x7B26CB4F,
	(q31_t)0x22847DDF, (q31_t)0x7B420D7A, (q31_t)0x2223A4C5,
	(q31_t)0x7B5D039D, (q31_t)0x21C2B69C, (q31_t)0x7B77ADA8,
	(q31_t)0x2161B39F, (q31_t)0x7B920B89, (q31_t)0x21009C0B,
	(q31_t)0x7BAC1D31, (q31_t)0x209F701C, (q31_t)0x7BC5E28F,
	(q31_t)0x203E300D, (q31_t)0x7BDF5B94, (q31_t)0x1FDCDC1A,
	(q31_t)0x7BF88830, (q31_t)0x1F7B7480, (q31_t)0x7C116853,
	(q31_t)0x1F19F97B, (q31_t)0x7C29FBEE, (q31_t)0x1EB86B46,
	(q31_t)0x7C4242F2, (q31_t)0x1E56CA1E, (q31_t)0x7C5A3D4F,
	(q31_t)0x1DF5163F, (q31_t)0x7C71EAF8, (q31_t)0x1D934FE5,
	(q31_t)0x7C894BDD, (q31_t)0x1D31774D, (q31_t)0x7CA05FF1,
	(q31_t)0x1CCF8CB3, (q31_t)0x7CB72724, (q31_t)0x1C6D9053,
	(q31_t)0x7CCDA168, (q31_t)0x1C0B826A, (q31_t)0x7CE3CEB1,
	(q31_t)0x1BA96334, (q31_t)0x7CF9AEF0, (q31_t)0x1B4732EF,
	(q31_t)0x7D0F4218, (q31_t)0x1AE4F1D6, (q31_t)0x7D24881A,
	(q31_t)0x1A82A025, (q31_t)0x7D3980EC, (q31_t)0x1A203E1B,
	(q31_t)0x7D4E2C7E, (q31_t)0x19BDCBF2, (q31_t)0x7D628AC5,
	(q31_t)0x195B49E9, (q31_t)0x7D769BB5, (q31_t)0x18F8B83C,
	(q31_t)0x7D8A5F3F, (q31_t)0x18961727, (q31_t)0x7D9DD55A,
	(q31_t)0x183366E8, (q31_t)0x7DB0FDF7, (q31_t)0x17D0A7BB,
	(q31_t)0x7DC3D90D, (q31_t)0x176DD9DE, (q31_t)0x7DD6668E,
	(q31_t)0x170AFD8D, (q31_t)0x7DE8A670, (q31_t)0x16A81305,
	(q31_t)0x7DFA98A7, (q31_t)0x16451A83, (q31_t)0x7E0C3D29,
	(q31_t)0x15E21444, (q31_t)0x7E1D93E9, (q31_t)0x157F0086,
	(q31_t)0x7E2E9CDF, (q31_t)0x151BDF85, (q31_t)0x7E3F57FE,
	(q31_t)0x14B8B17F, (q31_t)0x7E4FC53E, (q31_t)0x145576B1,
	(q31_t)0x7E5FE493, (q31_t)0x13F22F57, (q31_t)0x7E6FB5F3,
	(q31_t)0x138EDBB0, (q31_t)0x7E7F3956, (q31_t)0x132B7BF9,
	(q31_t)0x7E8E6EB1, (q31_t)0x12C8106E, (q31_t)0x7E9D55FC,
	(q31_t)0x1264994E, (q31_t)0x7EABEF2C, (q31_t)0x120116D4,
	(q31_t)0x7EBA3A39, (q31_t)0x119D8940, (q31_t)0x7EC8371A,
	(q31_t)0x1139F0CE, (q31_t)0x7ED5E5C6, (q31_t)0x10D64DBC,
	(q31_t)0x7EE34635, (q31_t)0x1072A047, (q31_t)0x7EF0585F,
	(q31_t)0x100EE8AD, (q31_t)0x7EFD1C3C, (q31_t)0x0FAB272B,
	(q31_t)0x7F0991C3, (q31_t)0x0F475BFE, (q31_t)0x7F15B8EE,
	(q31_t)0x0EE38765, (q31_t)0x7F2191B4, (q31_t)0x0E7FA99D,
	(q31_t)0x7F2D1C0E, (q31_t)0x0E1BC2E3, (q31_t)0x7F3857F5,
	(q31_t)0x0DB7D376, (q31_t)0x7F434563, (q31_t)0x0D53DB92,
	(q31_t)0x7F4DE450, (q31_t)0x0CEFDB75, (q31_t)0x7F5834B6,
	(q31_t)0x0C8BD35E, (q31_t)0x7F62368F, (q31_t)0x0C27C389,
	(q31_t)0x7F6BE9D4, (q31_t)0x0BC3AC35, (q31_t)0x7F754E7F,
	(q31_t)0x0B5F8D9F, (q31_t)0x7F7E648B, (q31_t)0x0AFB6805,
	(q31_t)0x7F872BF3, (q31_t)0x0A973BA5, (q31_t)0x7F8FA4AF,
	(q31_t)0x0A3308BC, (q31_t)0x7F97CEBC, (q31_t)0x09CECF89,
	(q31_t)0x7F9FAA15, (q31_t)0x096A9049, (q31_t)0x7FA736B4,
	(q31_t)0x09064B3A, (q31_t)0x7FAE7494, (q31_t)0x08A2009A,
	(q31_t)0x7FB563B2, (q31_t)0x083DB0A7, (q31_t)0x7FBC040A,
	(q31_t)0x07D95B9E, (q31_t)0x7FC25596, (q31_t)0x077501BE,
	(q31_t)0x7FC85853, (q31_t)0x0710A344, (q31_t)0x7FCE0C3E,
	(q31_t)0x06AC406F, (q31_t)0x7FD37152, (q31_t)0x0647D97C,
	(q31_t)0x7FD8878D, (q31_t)0x05E36EA9, (q31_t)0x7FDD4EEC,
	(q31_t)0x057F0034, (q31_t)0x7FE1C76B, (q31_t)0x051A8E5C,
	(q31_t)0x7FE5F108, (q31_t)0x04B6195D, (q31_t)0x7FE9CBC0,
	(q31_t)0x0451A176, (q31_t)0x7FED5790, (q31_t)0x03ED26E6,
	(q31_t)0x7FF09477, (q31_t)0x0388A9E9, (q31_t)0x7FF38273,
	(q31_t)0x03242ABF, (q31_t)0x7FF62182, (q31_t)0x02BFA9A4,
	(q31_t)0x7FF871A1, (q31_t)0x025B26D7, (q31_t)0x7FFA72D1,
	(q31_t)0x01F6A296, (q31_t)0x7FFC250F, (q31_t)0x01921D1F,
	(q31_t)0x7FFD885A, (q31_t)0x012D96B0, (q31_t)0x7FFE9CB2,
	(q31_t)0x00C90F88, (q31_t)0x7FFF6216, (q31_t)0x006487E3,
	(q31_t)0x7FFFD885, (q31_t)0x00000000, (q31_t)0x7FFFFFFF,
	(q31_t)0xFF9B781D, (q31_t)0x7FFFD885, (q31_t)0xFF36F078,
	(q31_t)0x7FFF6216, (q31_t)0xFED2694F, (q31_t)0x7FFE9CB2,
	(q31_t)0xFE6DE2E0, (q31_t)0x7FFD885A, (q31_t)0xFE095D69,
	(q31_t)0x7FFC250F, (q31_t)0xFDA4D928, (q31_t)0x7FFA72D1,
	(q31_t)0xFD40565B, (q31_t)0x7FF871A1, (q31_t)0xFCDBD541,
	(q31_t)0x7FF62182, (q31_t)0xFC775616, (q31_t)0x7FF38273,
	(q31_t)0xFC12D919, (q31_t)0x7FF09477, (q31_t)0xFBAE5E89,
	(q31_t)0x7FED5790, (q31_t)0xFB49E6A2, (q31_t)0x7FE9CBC0,
	(q31_t)0xFAE571A4, (q31_t)0x7FE5F108, (q31_t)0xFA80FFCB,
	(q31_t)0x7FE1C76B, (q31_t)0xFA1C9156, (q31_t)0x7FDD4EEC,
	(q31_t)0xF9B82683, (q31_t)0x7FD8878D, (q31_t)0xF953BF90,
	(q31_t)0x7FD37152, (q31_t)0xF8EF5CBB, (q31_t)0x7FCE0C3E,
	(q31_t)0xF88AFE41, (q31_t)0x7FC85853, (q31_t)0xF826A461,
	(q31_t)0x7FC25596, (q31_t)0xF7C24F58, (q31_t)0x7FBC040A,
	(q31_t)0xF75DFF65, (q31_t)0x7FB563B2, (q31_t)0xF6F9B4C5,
	(q31_t)0x7FAE7494, (q31_t)0xF6956FB6, (q31_t)0x7FA736B4,
	(q31_t)0xF6313076, (q31_t)0x7F9FAA15, (q31_t)0xF5CCF743,
	(q31_t)0x7F97CEBC, (q31_t)0xF568C45A, (q31_t)0x7F8FA4AF,
	(q31_t)0xF50497FA, (q31_t)0x7F872BF3, (q31_t)0xF4A07260,
	(q31_t)0x7F7E648B, (q31_t)0xF43C53CA, (q31_t)0x7F754E7F,
	(q31_t)0xF3D83C76, (q31_t)0x7F6BE9D4, (q31_t)0xF3742CA1,
	(q31_t)0x7F62368F, (q31_t)0xF310248A, (q31_t)0x7F5834B6,
	(q31_t)0xF2AC246D, (q31_t)0x7F4DE450, (q31_t)0xF2482C89,
	(q31_t)0x7F434563, (q31_t)0xF1E43D1C, (q31_t)0x7F3857F5,
	(q31_t)0xF1805662, (q31_t)0x7F2D1C0E, (q31_t)0xF11C789A,
	(q31_t)0x7F2191B4, (q31_t)0xF0B8A401, (q31_t)0x7F15B8EE,
	(q31_t)0xF054D8D4, (q31_t)0x7F0991C3, (q31_t)0xEFF11752,
	(q31_t)0x7EFD1C3C, (q31_t)0xEF8D5FB8, (q31_t)0x7EF0585F,
	(q31_t)0xEF29B243, (q31_t)0x7EE34635, (q31_t)0xEEC60F31,
	(q31_t)0x7ED5E5C6, (q31_t)0xEE6276BF, (q31_t)0x7EC8371A,
	(q31_t)0xEDFEE92B, (q31_t)0x7EBA3A39, (q31_t)0xED9B66B2,
	(q31_t)0x7EABEF2C, (q31_t)0xED37EF91, (q31_t)0x7E9D55FC,
	(q31_t)0xECD48406, (q31_t)0x7E8E6EB1, (q31_t)0xEC71244F,
	(q31_t)0x7E7F3956, (q31_t)0xEC0DD0A8, (q31_t)0x7E6FB5F3,
	(q31_t)0xEBAA894E, (q31_t)0x7E5FE493, (q31_t)0xEB474E80,
	(q31_t)0x7E4FC53E, (q31_t)0xEAE4207A, (q31_t)0x7E3F57FE,
	(q31_t)0xEA80FF79, (q31_t)0x7E2E9CDF, (q31_t)0xEA1DEBBB,
	(q31_t)0x7E1D93E9, (q31_t)0xE9BAE57C, (q31_t)0x7E0C3D29,
	(q31_t)0xE957ECFB, (q31_t)0x7DFA98A7, (q31_t)0xE8F50273,
	(q31_t)0x7DE8A670, (q31_t)0xE8922621, (q31_t)0x7DD6668E,
	(q31_t)0xE82F5844, (q31_t)0x7DC3D90D, (q31_t)0xE7CC9917,
	(q31_t)0x7DB0FDF7, (q31_t)0xE769E8D8, (q31_t)0x7D9DD55A,
	(q31_t)0xE70747C3, (q31_t)0x7D8A5F3F, (q31_t)0xE6A4B616,
	(q31_t)0x7D769BB5, (q31_t)0xE642340D, (q31_t)0x7D628AC5,
	(q31_t)0xE5DFC1E4, (q31_t)0x7D4E2C7E, (q31_t)0xE57D5FDA,
	(q31_t)0x7D3980EC, (q31_t)0xE51B0E2A, (q31_t)0x7D24881A,
	(q31_t)0xE4B8CD10, (q31_t)0x7D0F4218, (q31_t)0xE4569CCB,
	(q31_t)0x7CF9AEF0, (q31_t)0xE3F47D95, (q31_t)0x7CE3CEB1,
	(q31_t)0xE3926FAC, (q31_t)0x7CCDA168, (q31_t)0xE330734C,
	(q31_t)0x7CB72724, (q31_t)0xE2CE88B2, (q31_t)0x7CA05FF1,
	(q31_t)0xE26CB01A, (q31_t)0x7C894BDD, (q31_t)0xE20AE9C1,
	(q31_t)0x7C71EAF8, (q31_t)0xE1A935E1, (q31_t)0x7C5A3D4F,
	(q31_t)0xE14794B9, (q31_t)0x7C4242F2, (q31_t)0xE0E60684,
	(q31_t)0x7C29FBEE, (q31_t)0xE0848B7F, (q31_t)0x7C116853,
	(q31_t)0xE02323E5, (q31_t)0x7BF88830, (q31_t)0xDFC1CFF2,
	(q31_t)0x7BDF5B94, (q31_t)0xDF608FE3, (q31_t)0x7BC5E28F,
	(q31_t)0xDEFF63F4, (q31_t)0x7BAC1D31, (q31_t)0xDE9E4C60,
	(q31_t)0x7B920B89, (q31_t)0xDE3D4963, (q31_t)0x7B77ADA8,
	(q31_t)0xDDDC5B3A, (q31_t)0x7B5D039D, (q31_t)0xDD7B8220,
	(q31_t)0x7B420D7A, (q31_t)0xDD1ABE51, (q31_t)0x7B26CB4F,
	(q31_t)0xDCBA1008, (q31_t)0x7B0B3D2C, (q31_t)0xDC597781,
	(q31_t)0x7AEF6323, (q31_t)0xDBF8F4F8, (q31_t)0x7AD33D45,
	(q31_t)0xDB9888A8, (q31_t)0x7AB6CBA3, (q31_t)0xDB3832CD,
	(q31_t)0x7A9A0E4F, (q31_t)0xDAD7F3A2, (q31_t)0x7A7D055B,
	(q31_t)0xDA77CB62, (q31_t)0x7A5FB0D8, (q31_t)0xDA17BA4A,
	(q31_t)0x7A4210D8, (q31_t)0xD9B7C093, (q31_t)0x7A24256E,
	(q31_t)0xD957DE7A, (q31_t)0x7A05EEAD, (q31_t)0xD8F81439,
	(q31_t)0x79E76CA6, (q31_t)0xD898620C, (q31_t)0x79C89F6D,
	(q31_t)0xD838C82D, (q31_t)0x79A98715, (q31_t)0xD7D946D7,
	(q31_t)0x798A23B1, (q31_t)0xD779DE46, (q31_t)0x796A7554,
	(q31_t)0xD71A8EB5, (q31_t)0x794A7C11, (q31_t)0xD6BB585D,
	(q31_t)0x792A37FE, (q31_t)0xD65C3B7B, (q31_t)0x7909A92C,
	(q31_t)0xD5FD3847, (q31_t)0x78E8CFB1, (q31_t)0xD59E4EFE,
	(q31_t)0x78C7ABA1, (q31_t)0xD53F7FDA, (q31_t)0x78A63D10,
	(q31_t)0xD4E0CB14, (q31_t)0x78848413, (q31_t)0xD48230E8,
	(q31_t)0x786280BF, (q31_t)0xD423B190, (q31_t)0x78403328,
	(q31_t)0xD3C54D46, (q31_t)0x781D9B64, (q31_t)0xD3670445,
	(q31_t)0x77FAB988, (q31_t)0xD308D6C6, (q31_t)0x77D78DAA,
	(q31_t)0xD2AAC504, (q31_t)0x77B417DF, (q31_t)0xD24CCF38,
	(q31_t)0x7790583D, (q31_t)0xD1EEF59E, (q31_t)0x776C4EDB,
	(q31_t)0xD191386D, (q31_t)0x7747FBCE, (q31_t)0xD13397E1,
	(q31_t)0x77235F2D, (q31_t)0xD0D61433, (q31_t)0x76FE790E,
	(q31_t)0xD078AD9D, (q31_t)0x76D94988, (q31_t)0xD01B6459,
	(q31_t)0x76B3D0B3, (q31_t)0xCFBE389F, (q31_t)0x768E0EA5,
	(q31_t)0xCF612AAA, (q31_t)0x76680376, (q31_t)0xCF043AB2,
	(q31_t)0x7641AF3C, (q31_t)0xCEA768F2, (q31_t)0x761B1211,
	(q31_t)0xCE4AB5A2, (q31_t)0x75F42C0A, (q31_t)0xCDEE20FC,
	(q31_t)0x75CCFD42, (q31_t)0xCD91AB38, (q31_t)0x75A585CF,
	(q31_t)0xCD355490, (q31_t)0x757DC5CA, (q31_t)0xCCD91D3D,
	(q31_t)0x7555BD4B, (q31_t)0xCC7D0577, (q31_t)0x752D6C6C,
	(q31_t)0xCC210D78, (q31_t)0x7504D345, (q31_t)0xCBC53578,
	(q31_t)0x74DBF1EF, (q31_t)0xCB697DB0, (q31_t)0x74B2C883,
	(q31_t)0xCB0DE658, (q31_t)0x7489571B, (q31_t)0xCAB26FA9,
	(q31_t)0x745F9DD1, (q31_t)0xCA5719DB, (q31_t)0x74359CBD,
	(q31_t)0xC9FBE527, (q31_t)0x740B53FA, (q31_t)0xC9A0D1C4,
	(q31_t)0x73E0C3A3, (q31_t)0xC945DFEC, (q31_t)0x73B5EBD0,
	(q31_t)0xC8EB0FD6, (q31_t)0x738ACC9E, (q31_t)0xC89061BA,
	(q31_t)0x735F6626, (q31_t)0xC835D5D0, (q31_t)0x7333B883,
	(q31_t)0xC7DB6C50, (q31_t)0x7307C3D0, (q31_t)0xC7812571,
	(q31_t)0x72DB8828, (q31_t)0xC727016C, (q31_t)0x72AF05A6,
	(q31_t)0xC6CD0079, (q31_t)0x72823C66, (q31_t)0xC67322CD,
	(q31_t)0x72552C84, (q31_t)0xC61968A2, (q31_t)0x7227D61C,
	(q31_t)0xC5BFD22E, (q31_t)0x71FA3948, (q31_t)0xC5665FA8,
	(q31_t)0x71CC5626, (q31_t)0xC50D1148, (q31_t)0x719E2CD2,
	(q31_t)0xC4B3E746, (q31_t)0x716FBD68, (q31_t)0xC45AE1D7,
	(q31_t)0x71410804, (q31_t)0xC4020132, (q31_t)0x71120CC5,
	(q31_t)0xC3A9458F, (q31_t)0x70E2CBC6, (q31_t)0xC350AF25,
	(q31_t)0x70B34524, (q31_t)0xC2F83E2A, (q31_t)0x708378FE,
	(q31_t)0xC29FF2D4, (q31_t)0x70536771, (q31_t)0xC247CD5A,
	(q31_t)0x70231099, (q31_t)0xC1EFCDF2, (q31_t)0x6FF27496,
	(q31_t)0xC197F4D3, (q31_t)0x6FC19385, (q31_t)0xC1404233,
	(q31_t)0x6F906D84, (q31_t)0xC0E8B648, (q31_t)0x6F5F02B1,
	(q31_t)0xC0915147, (q31_t)0x6F2D532C, (q31_t)0xC03A1368,
	(q31_t)0x6EFB5F12, (q31_t)0xBFE2FCDF, (q31_t)0x6EC92682,
	(q31_t)0xBF8C0DE2, (q31_t)0x6E96A99C, (q31_t)0xBF3546A8,
	(q31_t)0x6E63E87F, (q31_t)0xBEDEA765, (q31_t)0x6E30E349,
	(q31_t)0xBE88304F, (q31_t)0x6DFD9A1B, (q31_t)0xBE31E19B,
	(q31_t)0x6DCA0D14, (q31_t)0xBDDBBB7F, (q31_t)0x6D963C54,
	(q31_t)0xBD85BE2F, (q31_t)0x6D6227FA, (q31_t)0xBD2FE9E1,
	(q31_t)0x6D2DD027, (q31_t)0xBCDA3ECA, (q31_t)0x6CF934FB,
	(q31_t)0xBC84BD1E, (q31_t)0x6CC45697, (q31_t)0xBC2F6513,
	(q31_t)0x6C8F351C, (q31_t)0xBBDA36DC, (q31_t)0x6C59D0A9,
	(q31_t)0xBB8532AF, (q31_t)0x6C242960, (q31_t)0xBB3058C0,
	(q31_t)0x6BEE3F62, (q31_t)0xBADBA943, (q31_t)0x6BB812D0,
	(q31_t)0xBA87246C, (q31_t)0x6B81A3CD, (q31_t)0xBA32CA70,
	(q31_t)0x6B4AF278, (q31_t)0xB9DE9B83, (q31_t)0x6B13FEF5,
	(q31_t)0xB98A97D8, (q31_t)0x6ADCC964, (q31_t)0xB936BFA3,
	(q31_t)0x6AA551E8, (q31_t)0xB8E31319, (q31_t)0x6A6D98A4,
	(q31_t)0xB88F926C, (q31_t)0x6A359DB9, (q31_t)0xB83C3DD1,
	(q31_t)0x69FD614A, (q31_t)0xB7E9157A, (q31_t)0x69C4E37A,
	(q31_t)0xB796199B, (q31_t)0x698C246C, (q31_t)0xB7434A67,
	(q31_t)0x69532442, (q31_t)0xB6F0A811, (q31_t)0x6919E320,
	(q31_t)0xB69E32CD, (q31_t)0x68E06129, (q31_t)0xB64BEACC,
	(q31_t)0x68A69E81, (q31_t)0xB5F9D042, (q31_t)0x686C9B4B,
	(q31_t)0xB5A7E362, (q31_t)0x683257AA, (q31_t)0xB556245E,
	(q31_t)0x67F7D3C4, (q31_t)0xB5049368, (q31_t)0x67BD0FBC,
	(q31_t)0xB4B330B2, (q31_t)0x67820BB6, (q31_t)0xB461FC70,
	(q31_t)0x6746C7D7, (q31_t)0xB410F6D2, (q31_t)0x670B4443,
	(q31_t)0xB3C0200C, (q31_t)0x66CF811F, (q31_t)0xB36F784E,
	(q31_t)0x66937E90, (q31_t)0xB31EFFCB, (q31_t)0x66573CBB,
	(q31_t)0xB2CEB6B5, (q31_t)0x661ABBC5, (q31_t)0xB27E9D3B,
	(q31_t)0x65DDFBD3, (q31_t)0xB22EB392, (q31_t)0x65A0FD0B,
	(q31_t)0xB1DEF9E8, (q31_t)0x6563BF92, (q31_t)0xB18F7070,
	(q31_t)0x6526438E, (q31_t)0xB140175B, (q31_t)0x64E88926,
	(q31_t)0xB0F0EEDA, (q31_t)0x64AA907F, (q31_t)0xB0A1F71C,
	(q31_t)0x646C59BF, (q31_t)0xB0533055, (q31_t)0x642DE50D,
	(q31_t)0xB0049AB2, (q31_t)0x63EF328F, (q31_t)0xAFB63667,
	(q31_t)0x63B0426D, (q31_t)0xAF6803A1, (q31_t)0x637114CC,
	(q31_t)0xAF1A0293, (q31_t)0x6331A9D4, (q31_t)0xAECC336B,
	(q31_t)0x62F201AC, (q31_t)0xAE7E965B, (q31_t)0x62B21C7B,
	(q31_t)0xAE312B91, (q31_t)0x6271FA69, (q31_t)0xADE3F33E,
	(q31_t)0x62319B9D, (q31_t)0xAD96ED91, (q31_t)0x61F1003E,
	(q31_t)0xAD4A1ABA, (q31_t)0x61B02876, (q31_t)0xACFD7AE8,
	(q31_t)0x616F146B, (q31_t)0xACB10E4A, (q31_t)0x612DC446,
	(q31_t)0xAC64D510, (q31_t)0x60EC3830, (q31_t)0xAC18CF68,
	(q31_t)0x60AA704F, (q31_t)0xABCCFD82, (q31_t)0x60686CCE,
	(q31_t)0xAB815F8C, (q31_t)0x60262DD5, (q31_t)0xAB35F5B5,
	(q31_t)0x5FE3B38D, (q31_t)0xAAEAC02B, (q31_t)0x5FA0FE1E,
	(q31_t)0xAA9FBF1D, (q31_t)0x5F5E0DB3, (q31_t)0xAA54F2B9,
	(q31_t)0x5F1AE273, (q31_t)0xAA0A5B2D, (q31_t)0x5ED77C89,
	(q31_t)0xA9BFF8A8, (q31_t)0x5E93DC1F, (q31_t)0xA975CB56,
	(q31_t)0x5E50015D, (q31_t)0xA92BD366, (q31_t)0x5E0BEC6E,
	(q31_t)0xA8E21106, (q31_t)0x5DC79D7C, (q31_t)0xA8988463,
	(q31_t)0x5D8314B0, (q31_t)0xA84F2DA9, (q31_t)0x5D3E5236,
	(q31_t)0xA8060D08, (q31_t)0x5CF95638, (q31_t)0xA7BD22AB,
	(q31_t)0x5CB420DF, (q31_t)0xA7746EC0, (q31_t)0x5C6EB258,
	(q31_t)0xA72BF173, (q31_t)0x5C290ACC, (q31_t)0xA6E3AAF2,
	(q31_t)0x5BE32A67, (q31_t)0xA69B9B68, (q31_t)0x5B9D1153,
	(q31_t)0xA653C302, (q31_t)0x5B56BFBD, (q31_t)0xA60C21ED,
	(q31_t)0x5B1035CF, (q31_t)0xA5C4B855, (q31_t)0x5AC973B4,
	(q31_t)0xA57D8666, (q31_t)0x5A82799A, (q31_t)0xA5368C4B,
	(q31_t)0x5A3B47AA, (q31_t)0xA4EFCA31, (q31_t)0x59F3DE12,
	(q31_t)0xA4A94042, (q31_t)0x59AC3CFD, (q31_t)0xA462EEAC,
	(q31_t)0x59646497, (q31_t)0xA41CD598, (q31_t)0x591C550E,
	(q31_t)0xA3D6F533, (q31_t)0x58D40E8C, (q31_t)0xA3914DA7,
	(q31_t)0x588B913F, (q31_t)0xA34BDF20, (q31_t)0x5842DD54,
	(q31_t)0xA306A9C7, (q31_t)0x57F9F2F7, (q31_t)0xA2C1ADC9,
	(q31_t)0x57B0D256, (q31_t)0xA27CEB4F, (q31_t)0x57677B9D,
	(q31_t)0xA2386283, (q31_t)0x571DEEF9, (q31_t)0xA1F41391,
	(q31_t)0x56D42C99, (q31_t)0xA1AFFEA2, (q31_t)0x568A34A9,
	(q31_t)0xA16C23E1, (q31_t)0x56400757, (q31_t)0xA1288376,
	(q31_t)0x55F5A4D2, (q31_t)0xA0E51D8C, (q31_t)0x55AB0D46,
	(q31_t)0xA0A1F24C, (q31_t)0x556040E2, (q31_t)0xA05F01E1,
	(q31_t)0x55153FD4, (q31_t)0xA01C4C72, (q31_t)0x54CA0A4A,
	(q31_t)0x9FD9D22A, (q31_t)0x547EA073, (q31_t)0x9F979331,
	(q31_t)0x5433027D, (q31_t)0x9F558FB0, (q31_t)0x53E73097,
	(q31_t)0x9F13C7D0, (q31_t)0x539B2AEF, (q31_t)0x9ED23BB9,
	(q31_t)0x534EF1B5, (q31_t)0x9E90EB94, (q31_t)0x53028517,
	(q31_t)0x9E4FD789, (q31_t)0x52B5E545, (q31_t)0x9E0EFFC1,
	(q31_t)0x5269126E, (q31_t)0x9DCE6462, (q31_t)0x521C0CC1,
	(q31_t)0x9D8E0596, (q31_t)0x51CED46E, (q31_t)0x9D4DE384,
	(q31_t)0x518169A4, (q31_t)0x9D0DFE53, (q31_t)0x5133CC94,
	(q31_t)0x9CCE562B, (q31_t)0x50E5FD6C, (q31_t)0x9C8EEB33,
	(q31_t)0x5097FC5E, (q31_t)0x9C4FBD92, (q31_t)0x5049C999,
	(q31_t)0x9C10CD70, (q31_t)0x4FFB654D, (q31_t)0x9BD21AF2,
	(q31_t)0x4FACCFAB, (q31_t)0x9B93A640, (q31_t)0x4F5E08E3,
	(q31_t)0x9B556F80, (q31_t)0x4F0F1126, (q31_t)0x9B1776D9,
	(q31_t)0x4EBFE8A4, (q31_t)0x9AD9BC71, (q31_t)0x4E708F8F,
	(q31_t)0x9A9C406D, (q31_t)0x4E210617, (q31_t)0x9A5F02F5,
	(q31_t)0x4DD14C6E, (q31_t)0x9A22042C, (q31_t)0x4D8162C4,
	(q31_t)0x99E5443A, (q31_t)0x4D31494B, (q31_t)0x99A8C344,
	(q31_t)0x4CE10034, (q31_t)0x996C816F, (q31_t)0x4C9087B1,
	(q31_t)0x99307EE0, (q31_t)0x4C3FDFF3, (q31_t)0x98F4BBBC,
	(q31_t)0x4BEF092D, (q31_t)0x98B93828, (q31_t)0x4B9E038F,
	(q31_t)0x987DF449, (q31_t)0x4B4CCF4D, (q31_t)0x9842F043,
	(q31_t)0x4AFB6C97, (q31_t)0x98082C3B, (q31_t)0x4AA9DBA1,
	(q31_t)0x97CDA855, (q31_t)0x4A581C9D, (q31_t)0x979364B5,
	(q31_t)0x4A062FBD, (q31_t)0x9759617E, (q31_t)0x49B41533,
	(q31_t)0x971F9ED6, (q31_t)0x4961CD32, (q31_t)0x96E61CDF,
	(q31_t)0x490F57EE, (q31_t)0x96ACDBBD, (q31_t)0x48BCB598,
	(q31_t)0x9673DB94, (q31_t)0x4869E664, (q31_t)0x963B1C85,
	(q31_t)0x4816EA85, (q31_t)0x96029EB5, (q31_t)0x47C3C22E,
	(q31_t)0x95CA6246, (q31_t)0x47706D93, (q31_t)0x9592675B,
	(q31_t)0x471CECE6, (q31_t)0x955AAE17, (q31_t)0x46C9405C,
	(q31_t)0x9523369B, (q31_t)0x46756827, (q31_t)0x94EC010B,
	(q31_t)0x4621647C, (q31_t)0x94B50D87, (q31_t)0x45CD358F,
	(q31_t)0x947E5C32, (q31_t)0x4578DB93, (q31_t)0x9447ED2F,
	(q31_t)0x452456BC, (q31_t)0x9411C09D, (q31_t)0x44CFA73F,
	(q31_t)0x93DBD69F, (q31_t)0x447ACD50, (q31_t)0x93A62F56,
	(q31_t)0x4425C923, (q31_t)0x9370CAE4, (q31_t)0x43D09AEC,
	(q31_t)0x933BA968, (q31_t)0x437B42E1, (q31_t)0x9306CB04,
	(q31_t)0x4325C135, (q31_t)0x92D22FD8, (q31_t)0x42D0161E,
	(q31_t)0x929DD805, (q31_t)0x427A41D0, (q31_t)0x9269C3AC,
	(q31_t)0x42244480, (q31_t)0x9235F2EB, (q31_t)0x41CE1E64,
	(q31_t)0x920265E4, (q31_t)0x4177CFB0, (q31_t)0x91CF1CB6,
	(q31_t)0x4121589A, (q31_t)0x919C1780, (q31_t)0x40CAB957,
	(q31_t)0x91695663, (q31_t)0x4073F21D, (q31_t)0x9136D97D,
	(q31_t)0x401D0320, (q31_t)0x9104A0ED, (q31_t)0x3FC5EC97,
	(q31_t)0x90D2ACD3, (q31_t)0x3F6EAEB8, (q31_t)0x90A0FD4E,
	(q31_t)0x3F1749B7, (q31_t)0x906F927B, (q31_t)0x3EBFBDCC,
	(q31_t)0x903E6C7A, (q31_t)0x3E680B2C, (q31_t)0x900D8B69,
	(q31_t)0x3E10320D, (q31_t)0x8FDCEF66, (q31_t)0x3DB832A5,
	(q31_t)0x8FAC988E, (q31_t)0x3D600D2B, (q31_t)0x8F7C8701,
	(q31_t)0x3D07C1D5, (q31_t)0x8F4CBADB, (q31_t)0x3CAF50DA,
	(q31_t)0x8F1D343A, (q31_t)0x3C56BA70, (q31_t)0x8EEDF33B,
	(q31_t)0x3BFDFECD, (q31_t)0x8EBEF7FB, (q31_t)0x3BA51E29,
	(q31_t)0x8E904298, (q31_t)0x3B4C18BA, (q31_t)0x8E61D32D,
	(q31_t)0x3AF2EEB7, (q31_t)0x8E33A9D9, (q31_t)0x3A99A057,
	(q31_t)0x8E05C6B7, (q31_t)0x3A402DD1, (q31_t)0x8DD829E4,
	(q31_t)0x39E6975D, (q31_t)0x8DAAD37B, (q31_t)0x398CDD32,
	(q31_t)0x8D7DC399, (q31_t)0x3932FF87, (q31_t)0x8D50FA59,
	(q31_t)0x38D8FE93, (q31_t)0x8D2477D8, (q31_t)0x387EDA8E,
	(q31_t)0x8CF83C30, (q31_t)0x382493B0, (q31_t)0x8CCC477D,
	(q31_t)0x37CA2A30, (q31_t)0x8CA099D9, (q31_t)0x376F9E46,
	(q31_t)0x8C753361, (q31_t)0x3714F02A, (q31_t)0x8C4A142F,
	(q31_t)0x36BA2013, (q31_t)0x8C1F3C5C, (q31_t)0x365F2E3B,
	(q31_t)0x8BF4AC05, (q31_t)0x36041AD9, (q31_t)0x8BCA6342,
	(q31_t)0x35A8E624, (q31_t)0x8BA0622F, (q31_t)0x354D9056,
	(q31_t)0x8B76A8E4, (q31_t)0x34F219A7, (q31_t)0x8B4D377C,
	(q31_t)0x3496824F, (q31_t)0x8B240E10, (q31_t)0x343ACA87,
	(q31_t)0x8AFB2CBA, (q31_t)0x33DEF287, (q31_t)0x8AD29393,
	(q31_t)0x3382FA88, (q31_t)0x8AAA42B4, (q31_t)0x3326E2C2,
	(q31_t)0x8A823A35, (q31_t)0x32CAAB6F, (q31_t)0x8A5A7A30,
	(q31_t)0x326E54C7, (q31_t)0x8A3302BD, (q31_t)0x3211DF03,
	(q31_t)0x8A0BD3F5, (q31_t)0x31B54A5D, (q31_t)0x89E4EDEE,
	(q31_t)0x3158970D, (q31_t)0x89BE50C3, (q31_t)0x30FBC54D,
	(q31_t)0x8997FC89, (q31_t)0x309ED555, (q31_t)0x8971F15A,
	(q31_t)0x3041C760, (q31_t)0x894C2F4C, (q31_t)0x2FE49BA6,
	(q31_t)0x8926B677, (q31_t)0x2F875262, (q31_t)0x890186F1,
	(q31_t)0x2F29EBCC, (q31_t)0x88DCA0D3, (q31_t)0x2ECC681E,
	(q31_t)0x88B80431, (q31_t)0x2E6EC792, (q31_t)0x8893B124,
	(q31_t)0x2E110A62, (q31_t)0x886FA7C2, (q31_t)0x2DB330C7,
	(q31_t)0x884BE820, (q31_t)0x2D553AFB, (q31_t)0x88287255,
	(q31_t)0x2CF72939, (q31_t)0x88054677, (q31_t)0x2C98FBBA,
	(q31_t)0x87E2649B, (q31_t)0x2C3AB2B9, (q31_t)0x87BFCCD7,
	(q31_t)0x2BDC4E6F, (q31_t)0x879D7F40, (q31_t)0x2B7DCF17,
	(q31_t)0x877B7BEC, (q31_t)0x2B1F34EB, (q31_t)0x8759C2EF,
	(q31_t)0x2AC08025, (q31_t)0x8738545E, (q31_t)0x2A61B101,
	(q31_t)0x8717304E, (q31_t)0x2A02C7B8, (q31_t)0x86F656D3,
	(q31_t)0x29A3C484, (q31_t)0x86D5C802, (q31_t)0x2944A7A2,
	(q31_t)0x86B583EE, (q31_t)0x28E5714A, (q31_t)0x86958AAB,
	(q31_t)0x288621B9, (q31_t)0x8675DC4E, (q31_t)0x2826B928,
	(q31_t)0x865678EA, (q31_t)0x27C737D2, (q31_t)0x86376092,
	(q31_t)0x27679DF4, (q31_t)0x86189359, (q31_t)0x2707EBC6,
	(q31_t)0x85FA1152, (q31_t)0x26A82185, (q31_t)0x85DBDA91,
	(q31_t)0x26483F6C, (q31_t)0x85BDEF27, (q31_t)0x25E845B5,
	(q31_t)0x85A04F28, (q31_t)0x2588349D, (q31_t)0x8582FAA4,
	(q31_t)0x25280C5D, (q31_t)0x8565F1B0, (q31_t)0x24C7CD32,
	(q31_t)0x8549345C, (q31_t)0x24677757, (q31_t)0x852CC2BA,
	(q31_t)0x24070B07, (q31_t)0x85109CDC, (q31_t)0x23A6887E,
	(q31_t)0x84F4C2D3, (q31_t)0x2345EFF7, (q31_t)0x84D934B0,
	(q31_t)0x22E541AE, (q31_t)0x84BDF285, (q31_t)0x22847DDF,
	(q31_t)0x84A2FC62, (q31_t)0x2223A4C5, (q31_t)0x84885257,
	(q31_t)0x21C2B69C, (q31_t)0x846DF476, (q31_t)0x2161B39F,
	(q31_t)0x8453E2CE, (q31_t)0x21009C0B, (q31_t)0x843A1D70,
	(q31_t)0x209F701C, (q31_t)0x8420A46B, (q31_t)0x203E300D,
	(q31_t)0x840777CF, (q31_t)0x1FDCDC1A, (q31_t)0x83EE97AC,
	(q31_t)0x1F7B7480, (q31_t)0x83D60411, (q31_t)0x1F19F97B,
	(q31_t)0x83BDBD0D, (q31_t)0x1EB86B46, (q31_t)0x83A5C2B0,
	(q31_t)0x1E56CA1E, (q31_t)0x838E1507, (q31_t)0x1DF5163F,
	(q31_t)0x8376B422, (q31_t)0x1D934FE5, (q31_t)0x835FA00E,
	(q31_t)0x1D31774D, (q31_t)0x8348D8DB, (q31_t)0x1CCF8CB3,
	(q31_t)0x83325E97, (q31_t)0x1C6D9053, (q31_t)0x831C314E,
	(q31_t)0x1C0B826A, (q31_t)0x8306510F, (q31_t)0x1BA96334,
	(q31_t)0x82F0BDE8, (q31_t)0x1B4732EF, (q31_t)0x82DB77E5,
	(q31_t)0x1AE4F1D6, (q31_t)0x82C67F13, (q31_t)0x1A82A025,
	(q31_t)0x82B1D381, (q31_t)0x1A203E1B, (q31_t)0x829D753A,
	(q31_t)0x19BDCBF2, (q31_t)0x8289644A, (q31_t)0x195B49E9,
	(q31_t)0x8275A0C0, (q31_t)0x18F8B83C, (q31_t)0x82622AA5,
	(q31_t)0x18961727, (q31_t)0x824F0208, (q31_t)0x183366E8,
	(q31_t)0x823C26F2, (q31_t)0x17D0A7BB, (q31_t)0x82299971,
	(q31_t)0x176DD9DE, (q31_t)0x8217598F, (q31_t)0x170AFD8D,
	(q31_t)0x82056758, (q31_t)0x16A81305, (q31_t)0x81F3C2D7,
	(q31_t)0x16451A83, (q31_t)0x81E26C16, (q31_t)0x15E21444,
	(q31_t)0x81D16320, (q31_t)0x157F0086, (q31_t)0x81C0A801,
	(q31_t)0x151BDF85, (q31_t)0x81B03AC1, (q31_t)0x14B8B17F,
	(q31_t)0x81A01B6C, (q31_t)0x145576B1, (q31_t)0x81904A0C,
	(q31_t)0x13F22F57, (q31_t)0x8180C6A9, (q31_t)0x138EDBB0,
	(q31_t)0x8171914E, (q31_t)0x132B7BF9, (q31_t)0x8162AA03,
	(q31_t)0x12C8106E, (q31_t)0x815410D3, (q31_t)0x1264994E,
	(q31_t)0x8145C5C6, (q31_t)0x120116D4, (q31_t)0x8137C8E6,
	(q31_t)0x119D8940, (q31_t)0x812A1A39, (q31_t)0x1139F0CE,
	(q31_t)0x811CB9CA, (q31_t)0x10D64DBC, (q31_t)0x810FA7A0,
	(q31_t)0x1072A047, (q31_t)0x8102E3C3, (q31_t)0x100EE8AD,
	(q31_t)0x80F66E3C, (q31_t)0x0FAB272B, (q31_t)0x80EA4712,
	(q31_t)0x0F475BFE, (q31_t)0x80DE6E4C, (q31_t)0x0EE38765,
	(q31_t)0x80D2E3F1, (q31_t)0x0E7FA99D, (q31_t)0x80C7A80A,
	(q31_t)0x0E1BC2E3, (q31_t)0x80BCBA9C, (q31_t)0x0DB7D376,
	(q31_t)0x80B21BAF, (q31_t)0x0D53DB92, (q31_t)0x80A7CB49,
	(q31_t)0x0CEFDB75, (q31_t)0x809DC970, (q31_t)0x0C8BD35E,
	(q31_t)0x8094162B, (q31_t)0x0C27C389, (q31_t)0x808AB180,
	(q31_t)0x0BC3AC35, (q31_t)0x80819B74, (q31_t)0x0B5F8D9F,
	(q31_t)0x8078D40D, (q31_t)0x0AFB6805, (q31_t)0x80705B50,
	(q31_t)0x0A973BA5, (q31_t)0x80683143, (q31_t)0x0A3308BC,
	(q31_t)0x806055EA, (q31_t)0x09CECF89, (q31_t)0x8058C94C,
	(q31_t)0x096A9049, (q31_t)0x80518B6B, (q31_t)0x09064B3A,
	(q31_t)0x804A9C4D, (q31_t)0x08A2009A, (q31_t)0x8043FBF6,
	(q31_t)0x083DB0A7, (q31_t)0x803DAA69, (q31_t)0x07D95B9E,
	(q31_t)0x8037A7AC, (q31_t)0x077501BE, (q31_t)0x8031F3C1,
	(q31_t)0x0710A344, (q31_t)0x802C8EAD, (q31_t)0x06AC406F,
	(q31_t)0x80277872, (q31_t)0x0647D97C, (q31_t)0x8022B113,
	(q31_t)0x05E36EA9, (q31_t)0x801E3894, (q31_t)0x057F0034,
	(q31_t)0x801A0EF7, (q31_t)0x051A8E5C, (q31_t)0x80163440,
	(q31_t)0x04B6195D, (q31_t)0x8012A86F, (q31_t)0x0451A176,
	(q31_t)0x800F6B88, (q31_t)0x03ED26E6, (q31_t)0x800C7D8C,
	(q31_t)0x0388A9E9, (q31_t)0x8009DE7D, (q31_t)0x03242ABF,
	(q31_t)0x80078E5E, (q31_t)0x02BFA9A4, (q31_t)0x80058D2E,
	(q31_t)0x025B26D7, (q31_t)0x8003DAF0, (q31_t)0x01F6A296,
	(q31_t)0x800277A5, (q31_t)0x01921D1F, (q31_t)0x8001634D,
	(q31_t)0x012D96B0, (q31_t)0x80009DE9, (q31_t)0x00C90F88,
	(q31_t)0x8000277A, (q31_t)0x006487E3, (q31_t)0x80000000,
	(q31_t)0x00000000, (q31_t)0x8000277A, (q31_t)0xFF9B781D,
	(q31_t)0x80009DE9, (q31_t)0xFF36F078, (q31_t)0x8001634D,
	(q31_t)0xFED2694F, (q31_t)0x800277A5, (q31_t)0xFE6DE2E0,
	(q31_t)0x8003DAF0, (q31_t)0xFE095D69, (q31_t)0x80058D2E,
	(q31_t)0xFDA4D928, (q31_t)0x80078E5E, (q31_t)0xFD40565B,
	(q31_t)0x8009DE7D, (q31_t)0xFCDBD541, (q31_t)0x800C7D8C,
	(q31_t)0xFC775616, (q31_t)0x800F6B88, (q31_t)0xFC12D919,
	(q31_t)0x8012A86F, (q31_t)0xFBAE5E89, (q31_t)0x80163440,
	(q31_t)0xFB49E6A2, (q31_t)0x801A0EF7, (q31_t)0xFAE571A4,
	(q31_t)0x801E3894, (q31_t)0xFA80FFCB, (q31_t)0x8022B113,
	(q31_t)0xFA1C9156, (q31_t)0x80277872, (q31_t)0xF9B82683,
	(q31_t)0x802C8EAD, (q31_t)0xF953BF90, (q31_t)0x8031F3C1,
	(q31_t)0xF8EF5CBB, (q31_t)0x8037A7AC, (q31_t)0xF88AFE41,
	(q31_t)0x803DAA69, (q31_t)0xF826A461, (q31_t)0x8043FBF6,
	(q31_t)0xF7C24F58, (q31_t)0x804A9C4D, (q31_t)0xF75DFF65,
	(q31_t)0x80518B6B, (q31_t)0xF6F9B4C5, (q31_t)0x8058C94C,
	(q31_t)0xF6956FB6, (q31_t)0x806055EA, (q31_t)0xF6313076,
	(q31_t)0x80683143, (q31_t)0xF5CCF743, (q31_t)0x80705B50,
	(q31_t)0xF568C45A, (q31_t)0x8078D40D, (q31_t)0xF50497FA,
	(q31_t)0x80819B74, (q31_t)0xF4A07260, (q31_t)0x808AB180,
	(q31_t)0xF43C53CA, (q31_t)0x8094162B, (q31_t)0xF3D83C76,
	(q31_t)0x809DC970, (q31_t)0xF3742CA1, (q31_t)0x80A7CB49,
	(q31_t)0xF310248A, (q31_t)0x80B21BAF, (q31_t)0xF2AC246D,
	(q31_t)0x80BCBA9C, (q31_t)0xF2482C89, (q31_t)0x80C7A80A,
	(q31_t)0xF1E43D1C, (q31_t)0x80D2E3F1, (q31_t)0xF1805662,
	(q31_t)0x80DE6E4C, (q31_t)0xF11C789A, (q31_t)0x80EA4712,
	(q31_t)0xF0B8A401, (q31_t)0x80F66E3C, (q31_t)0xF054D8D4,
	(q31_t)0x8102E3C3, (q31_t)0xEFF11752, (q31_t)0x810FA7A0,
	(q31_t)0xEF8D5FB8, (q31_t)0x811CB9CA, (q31_t)0xEF29B243,
	(q31_t)0x812A1A39, (q31_t)0xEEC60F31, (q31_t)0x8137C8E6,
	(q31_t)0xEE6276BF, (q31_t)0x8145C5C6, (q31_t)0xEDFEE92B,
	(q31_t)0x815410D3, (q31_t)0xED9B66B2, (q31_t)0x8162AA03,
	(q31_t)0xED37EF91, (q31_t)0x8171914E, (q31_t)0xECD48406,
	(q31_t)0x8180C6A9, (q31_t)0xEC71244F, (q31_t)0x81904A0C,
	(q31_t)0xEC0DD0A8, (q31_t)0x81A01B6C, (q31_t)0xEBAA894E,
	(q31_t)0x81B03AC1, (q31_t)0xEB474E80, (q31_t)0x81C0A801,
	(q31_t)0xEAE4207A, (q31_t)0x81D16320, (q31_t)0xEA80FF79,
	(q31_t)0x81E26C16, (q31_t)0xEA1DEBBB, (q31_t)0x81F3C2D7,
	(q31_t)0xE9BAE57C, (q31_t)0x82056758, (q31_t)0xE957ECFB,
	(q31_t)0x8217598F, (q31_t)0xE8F50273, (q31_t)0x82299971,
	(q31_t)0xE8922621, (q31_t)0x823C26F2, (q31_t)0xE82F5844,
	(q31_t)0x824F0208, (q31_t)0xE7CC9917, (q31_t)0x82622AA5,
	(q31_t)0xE769E8D8, (q31_t)0x8275A0C0, (q31_t)0xE70747C3,
	(q31_t)0x8289644A, (q31_t)0xE6A4B616, (q31_t)0x829D753A,
	(q31_t)0xE642340D, (q31_t)0x82B1D381, (q31_t)0xE5DFC1E4,
	(q31_t)0x82C67F13, (q31_t)0xE57D5FDA, (q31_t)0x82DB77E5,
	(q31_t)0xE51B0E2A, (q31_t)0x82F0BDE8, (q31_t)0xE4B8CD10,
	(q31_t)0x8306510F, (q31_t)0xE4569CCB, (q31_t)0x831C314E,
	(q31_t)0xE3F47D95, (q31_t)0x83325E97, (q31_t)0xE3926FAC,
	(q31_t)0x8348D8DB, (q31_t)0xE330734C, (q31_t)0x835FA00E,
	(q31_t)0xE2CE88B2, (q31_t)0x8376B422, (q31_t)0xE26CB01A,
	(q31_t)0x838E1507, (q31_t)0xE20AE9C1, (q31_t)0x83A5C2B0,
	(q31_t)0xE1A935E1, (q31_t)0x83BDBD0D, (q31_t)0xE14794B9,
	(q31_t)0x83D60411, (q31_t)0xE0E60684, (q31_t)0x83EE97AC,
	(q31_t)0xE0848B7F, (q31_t)0x840777CF, (q31_t)0xE02323E5,
	(q31_t)0x8420A46B, (q31_t)0xDFC1CFF2, (q31_t)0x843A1D70,
	(q31_t)0xDF608FE3, (q31_t)0x8453E2CE, (q31_t)0xDEFF63F4,
	(q31_t)0x846DF476, (q31_t)0xDE9E4C60, (q31_t)0x84885257,
	(q31_t)0xDE3D4963, (q31_t)0x84A2FC62, (q31_t)0xDDDC5B3A,
	(q31_t)0x84BDF285, (q31_t)0xDD7B8220, (q31_t)0x84D934B0,
	(q31_t)0xDD1ABE51, (q31_t)0x84F4C2D3, (q31_t)0xDCBA1008,
	(q31_t)0x85109CDC, (q31_t)0xDC597781, (q31_t)0x852CC2BA,
	(q31_t)0xDBF8F4F8, (q31_t)0x8549345C, (q31_t)0xDB9888A8,
	(q31_t)0x8565F1B0, (q31_t)0xDB3832CD, (q31_t)0x8582FAA4,
	(q31_t)0xDAD7F3A2, (q31_t)0x85A04F28, (q31_t)0xDA77CB62,
	(q31_t)0x85BDEF27, (q31_t)0xDA17BA4A, (q31_t)0x85DBDA91,
	(q31_t)0xD9B7C093, (q31_t)0x85FA1152, (q31_t)0xD957DE7A,
	(q31_t)0x86189359, (q31_t)0xD8F81439, (q31_t)0x86376092,
	(q31_t)0xD898620C, (q31_t)0x865678EA, (q31_t)0xD838C82D,
	(q31_t)0x8675DC4E, (q31_t)0xD7D946D7, (q31_t)0x86958AAB,
	(q31_t)0xD779DE46, (q31_t)0x86B583EE, (q31_t)0xD71A8EB5,
	(q31_t)0x86D5C802, (q31_t)0xD6BB585D, (q31_t)0x86F656D3,
	(q31_t)0xD65C3B7B, (q31_t)0x8717304E, (q31_t)0xD5FD3847,
	(q31_t)0x8738545E, (q31_t)0xD59E4EFE, (q31_t)0x8759C2EF,
	(q31_t)0xD53F7FDA, (q31_t)0x877B7BEC, (q31_t)0xD4E0CB14,
	(q31_t)0x879D7F40, (q31_t)0xD48230E8, (q31_t)0x87BFCCD7,
	(q31_t)0xD423B190, (q31_t)0x87E2649B, (q31_t)0xD3C54D46,
	(q31_t)0x88054677, (q31_t)0xD3670445, (q31_t)0x88287255,
	(q31_t)0xD308D6C6, (q31_t)0x884BE820, (q31_t)0xD2AAC504,
	(q31_t)0x886FA7C2, (q31_t)0xD24CCF38, (q31_t)0x8893B124,
	(q31_t)0xD1EEF59E, (q31_t)0x88B80431, (q31_t)0xD191386D,
	(q31_t)0x88DCA0D3, (q31_t)0xD13397E1, (q31_t)0x890186F1,
	(q31_t)0xD0D61433, (q31_t)0x8926B677, (q31_t)0xD078AD9D,
	(q31_t)0x894C2F4C, (q31_t)0xD01B6459, (q31_t)0x8971F15A,
	(q31_t)0xCFBE389F, (q31_t)0x8997FC89, (q31_t)0xCF612AAA,
	(q31_t)0x89BE50C3, (q31_t)0xCF043AB2, (q31_t)0x89E4EDEE,
	(q31_t)0xCEA768F2, (q31_t)0x8A0BD3F5, (q31_t)0xCE4AB5A2,
	(q31_t)0x8A3302BD, (q31_t)0xCDEE20FC, (q31_t)0x8A5A7A30,
	(q31_t)0xCD91AB38, (q31_t)0x8A823A35, (q31_t)0xCD355490,
	(q31_t)0x8AAA42B4, (q31_t)0xCCD91D3D, (q31_t)0x8AD29393,
	(q31_t)0xCC7D0577, (q31_t)0x8AFB2CBA, (q31_t)0xCC210D78,
	(q31_t)0x8B240E10, (q31_t)0xCBC53578, (q31_t)0x8B4D377C,
	(q31_t)0xCB697DB0, (q31_t)0x8B76A8E4, (q31_t)0xCB0DE658,
	(q31_t)0x8BA0622F, (q31_t)0xCAB26FA9, (q31_t)0x8BCA6342,
	(q31_t)0xCA5719DB, (q31_t)0x8BF4AC05, (q31_t)0xC9FBE527,
	(q31_t)0x8C1F3C5C, (q31_t)0xC9A0D1C4, (q31_t)0x8C4A142F,
	(q31_t)0xC945DFEC, (q31_t)0x8C753361, (q31_t)0xC8EB0FD6,
	(q31_t)0x8CA099D9, (q31_t)0xC89061BA, (q31_t)0x8CCC477D,
	(q31_t)0xC835D5D0, (q31_t)0x8CF83C30, (q31_t)0xC7DB6C50,
	(q31_t)0x8D2477D8, (q31_t)0xC7812571, (q31_t)0x8D50FA59,
	(q31_t)0xC727016C, (q31_t)0x8D7DC399, (q31_t)0xC6CD0079,
	(q31_t)0x8DAAD37B, (q31_t)0xC67322CD, (q31_t)0x8DD829E4,
	(q31_t)0xC61968A2, (q31_t)0x8E05C6B7, (q31_t)0xC5BFD22E,
	(q31_t)0x8E33A9D9, (q31_t)0xC5665FA8, (q31_t)0x8E61D32D,
	(q31_t)0xC50D1148, (q31_t)0x8E904298, (q31_t)0xC4B3E746,
	(q31_t)0x8EBEF7FB, (q31_t)0xC45AE1D7, (q31_t)0x8EEDF33B,
	(q31_t)0xC4020132, (q31_t)0x8F1D343A, (q31_t)0xC3A9458F,
	(q31_t)0x8F4CBADB, (q31_t)0xC350AF25, (q31_t)0x8F7C8701,
	(q31_t)0xC2F83E2A, (q31_t)0x8FAC988E, (q31_t)0xC29FF2D4,
	(q31_t)0x8FDCEF66, (q31_t)0xC247CD5A, (q31_t)0x900D8B69,
	(q31_t)0xC1EFCDF2, (q31_t)0x903E6C7A, (q31_t)0xC197F4D3,
	(q31_t)0x906F927B, (q31_t)0xC1404233, (q31_t)0x90A0FD4E,
	(q31_t)0xC0E8B648, (q31_t)0x90D2ACD3, (q31_t)0xC0915147,
	(q31_t)0x9104A0ED, (q31_t)0xC03A1368, (q31_t)0x9136D97D,
	(q31_t)0xBFE2FCDF, (q31_t)0x91695663, (q31_t)0xBF8C0DE2,
	(q31_t)0x919C1780, (q31_t)0xBF3546A8, (q31_t)0x91CF1CB6,
	(q31_t)0xBEDEA765, (q31_t)0x920265E4, (q31_t)0xBE88304F,
	(q31_t)0x9235F2EB, (q31_t)0xBE31E19B, (q31_t)0x9269C3AC,
	(q31_t)0xBDDBBB7F, (q31_t)0x929DD805, (q31_t)0xBD85BE2F,
	(q31_t)0x92D22FD8, (q31_t)0xBD2FE9E1, (q31_t)0x9306CB04,
	(q31_t)0xBCDA3ECA, (q31_t)0x933BA968, (q31_t)0xBC84BD1E,
	(q31_t)0x9370CAE4, (q31_t)0xBC2F6513, (q31_t)0x93A62F56,
	(q31_t)0xBBDA36DC, (q31_t)0x93DBD69F, (q31_t)0xBB8532AF,
	(q31_t)0x9411C09D, (q31_t)0xBB3058C0, (q31_t)0x9447ED2F,
	(q31_t)0xBADBA943, (q31_t)0x947E5C32, (q31_t)0xBA87246C,
	(q31_t)0x94B50D87, (q31_t)0xBA32CA70, (q31_t)0x94EC010B,
	(q31_t)0xB9DE9B83, (q31_t)0x9523369B, (q31_t)0xB98A97D8,
	(q31_t)0x955AAE17, (q31_t)0xB936BFA3, (q31_t)0x9592675B,
	(q31_t)0xB8E31319, (q31_t)0x95CA6246, (q31_t)0xB88F926C,
	(q31_t)0x96029EB5, (q31_t)0xB83C3DD1, (q31_t)0x963B1C85,
	(q31_t)0xB7E9157A, (q31_t)0x9673DB94, (q31_t)0xB796199B,
	(q31_t)0x96ACDBBD, (q31_t)0xB7434A67, (q31_t)0x96E61CDF,
	(q31_t)0xB6F0A811, (q31_t)0x971F9ED6, (q31_t)0xB69E32CD,
	(q31_t)0x9759617E, (q31_t)0xB64BEACC, (q31_t)0x979364B5,
	(q31_t)0xB5F9D042, (q31_t)0x97CDA855, (q31_t)0xB5A7E362,
	(q31_t)0x98082C3B, (q31_t)0xB556245E, (q31_t)0x9842F043,
	(q31_t)0xB5049368, (q31_t)0x987DF449, (q31_t)0xB4B330B2,
	(q31_t)0x98B93828, (q31_t)0xB461FC70, (q31_t)0x98F4BBBC,
	(q31_t)0xB410F6D2, (q31_t)0x99307EE0, (q31_t)0xB3C0200C,
	(q31_t)0x996C816F, (q31_t)0xB36F784E, (q31_t)0x99A8C344,
	(q31_t)0xB31EFFCB, (q31_t)0x99E5443A, (q31_t)0xB2CEB6B5,
	(q31_t)0x9A22042C, (q31_t)0xB27E9D3B, (q31_t)0x9A5F02F5,
	(q31_t)0xB22EB392, (q31_t)0x9A9C406D, (q31_t)0xB1DEF9E8,
	(q31_t)0x9AD9BC71, (q31_t)0xB18F7070, (q31_t)0x9B1776D9,
	(q31_t)0xB140175B, (q31_t)0x9B556F80, (q31_t)0xB0F0EEDA,
	(q31_t)0x9B93A640, (q31_t)0xB0A1F71C, (q31_t)0x9BD21AF2,
	(q31_t)0xB0533055, (q31_t)0x9C10CD70, (q31_t)0xB0049AB2,
	(q31_t)0x9C4FBD92, (q31_t)0xAFB63667, (q31_t)0x9C8EEB33,
	(q31_t)0xAF6803A1, (q31_t)0x9CCE562B, (q31_t)0xAF1A0293,
	(q31_t)0x9D0DFE53, (q31_t)0xAECC336B, (q31_t)0x9D4DE384,
	(q31_t)0xAE7E965B, (q31_t)0x9D8E0596, (q31_t)0xAE312B91,
	(q31_t)0x9DCE6462, (q31_t)0xADE3F33E, (q31_t)0x9E0EFFC1,
	(q31_t)0xAD96ED91, (q31_t)0x9E4FD789, (q31_t)0xAD4A1ABA,
	(q31_t)0x9E90EB94, (q31_t)0xACFD7AE8, (q31_t)0x9ED23BB9,
	(q31_t)0xACB10E4A, (q31_t)0x9F13C7D0, (q31_t)0xAC64D510,
	(q31_t)0x9F558FB0, (q31_t)0xAC18CF68, (q31_t)0x9F979331,
	(q31_t)0xABCCFD82, (q31_t)0x9FD9D22A, (q31_t)0xAB815F8C,
	(q31_t)0xA01C4C72, (q31_t)0xAB35F5B5, (q31_t)0xA05F01E1,
	(q31_t)0xAAEAC02B, (q31_t)0xA0A1F24C, (q31_t)0xAA9FBF1D,
	(q31_t)0xA0E51D8C, (q31_t)0xAA54F2B9, (q31_t)0xA1288376,
	(q31_t)0xAA0A5B2D, (q31_t)0xA16C23E1, (q31_t)0xA9BFF8A8,
	(q31_t)0xA1AFFEA2, (q31_t)0xA975CB56, (q31_t)0xA1F41391,
	(q31_t)0xA92BD366, (q31_t)0xA2386283, (q31_t)0xA8E21106,
	(q31_t)0xA27CEB4F, (q31_t)0xA8988463, (q31_t)0xA2C1ADC9,
	(q31_t)0xA84F2DA9, (q31_t)0xA306A9C7, (q31_t)0xA8060D08,
	(q31_t)0xA34BDF20, (q31_t)0xA7BD22AB, (q31_t)0xA3914DA7,
	(q31_t)0xA7746EC0, (q31_t)0xA3D6F533, (q31_t)0xA72BF173,
	(q31_t)0xA41CD598, (q31_t)0xA6E3AAF2, (q31_t)0xA462EEAC,
	(q31_t)0xA69B9B68, (q31_t)0xA4A94042, (q31_t)0xA653C302,
	(q31_t)0xA4EFCA31, (q31_t)0xA60C21ED, (q31_t)0xA5368C4B,
	(q31_t)0xA5C4B855, (q31_t)0xA57D8666, (q31_t)0xA57D8666,
	(q31_t)0xA5C4B855, (q31_t)0xA5368C4B, (q31_t)0xA60C21ED,
	(q31_t)0xA4EFCA31, (q31_t)0xA653C302, (q31_t)0xA4A94042,
	(q31_t)0xA69B9B68, (q31_t)0xA462EEAC, (q31_t)0xA6E3AAF2,
	(q31_t)0xA41CD598, (q31_t)0xA72BF173, (q31_t)0xA3D6F533,
	(q31_t)0xA7746EC0, (q31_t)0xA3914DA7, (q31_t)0xA7BD22AB,
	(q31_t)0xA34BDF20, (q31_t)0xA8060D08, (q31_t)0xA306A9C7,
	(q31_t)0xA84F2DA9, (q31_t)0xA2C1ADC9, (q31_t)0xA8988463,
	(q31_t)0xA27CEB4F, (q31_t)0xA8E21106, (q31_t)0xA2386283,
	(q31_t)0xA92BD366, (q31_t)0xA1F41391, (q31_t)0xA975CB56,
	(q31_t)0xA1AFFEA2, (q31_t)0xA9BFF8A8, (q31_t)0xA16C23E1,
	(q31_t)0xAA0A5B2D, (q31_t)0xA1288376, (q31_t)0xAA54F2B9,
	(q31_t)0xA0E51D8C, (q31_t)0xAA9FBF1D, (q31_t)0xA0A1F24C,
	(q31_t)0xAAEAC02B, (q31_t)0xA05F01E1, (q31_t)0xAB35F5B5,
	(q31_t)0xA01C4C72, (q31_t)0xAB815F8C, (q31_t)0x9FD9D22A,
	(q31_t)0xABCCFD82, (q31_t)0x9F979331, (q31_t)0xAC18CF68,
	(q31_t)0x9F558FB0, (q31_t)0xAC64D510, (q31_t)0x9F13C7D0,
	(q31_t)0xACB10E4A, (q31_t)0x9ED23BB9, (q31_t)0xACFD7AE8,
	(q31_t)0x9E90EB94, (q31_t)0xAD4A1ABA, (q31_t)0x9E4FD789,
	(q31_t)0xAD96ED91, (q31_t)0x9E0EFFC1, (q31_t)0xADE3F33E,
	(q31_t)0x9DCE6462, (q31_t)0xAE312B91, (q31_t)0x9D8E0596,
	(q31_t)0xAE7E965B, (q31_t)0x9D4DE384, (q31_t)0xAECC336B,
	(q31_t)0x9D0DFE53, (q31_t)0xAF1A0293, (q31_t)0x9CCE562B,
	(q31_t)0xAF6803A1, (q31_t)0x9C8EEB33, (q31_t)0xAFB63667,
	(q31_t)0x9C4FBD92, (q31_t)0xB0049AB2, (q31_t)0x9C10CD70,
	(q31_t)0xB0533055, (q31_t)0x9BD21AF2, (q31_t)0xB0A1F71C,
	(q31_t)0x9B93A640, (q31_t)0xB0F0EEDA, (q31_t)0x9B556F80,
	(q31_t)0xB140175B, (q31_t)0x9B1776D9, (q31_t)0xB18F7070,
	(q31_t)0x9AD9BC71, (q31_t)0xB1DEF9E8, (q31_t)0x9A9C406D,
	(q31_t)0xB22EB392, (q31_t)0x9A5F02F5, (q31_t)0xB27E9D3B,
	(q31_t)0x9A22042C, (q31_t)0xB2CEB6B5, (q31_t)0x99E5443A,
	(q31_t)0xB31EFFCB, (q31_t)0x99A8C344, (q31_t)0xB36F784E,
	(q31_t)0x996C816F, (q31_t)0xB3C0200C, (q31_t)0x99307EE0,
	(q31_t)0xB410F6D2, (q31_t)0x98F4BBBC, (q31_t)0xB461FC70,
	(q31_t)0x98B93828, (q31_t)0xB4B330B2, (q31_t)0x987DF449,
	(q31_t)0xB5049368, (q31_t)0x9842F043, (q31_t)0xB556245E,
	(q31_t)0x98082C3B, (q31_t)0xB5A7E362, (q31_t)0x97CDA855,
	(q31_t)0xB5F9D042, (q31_t)0x979364B5, (q31_t)0xB64BEACC,
	(q31_t)0x9759617E, (q31_t)0xB69E32CD, (q31_t)0x971F9ED6,
	(q31_t)0xB6F0A811, (q31_t)0x96E61CDF, (q31_t)0xB7434A67,
	(q31_t)0x96ACDBBD, (q31_t)0xB796199B, (q31_t)0x9673DB94,
	(q31_t)0xB7E9157A, (q31_t)0x963B1C85, (q31_t)0xB83C3DD1,
	(q31_t)0x96029EB5, (q31_t)0xB88F926C, (q31_t)0x95CA6246,
	(q31_t)0xB8E31319, (q31_t)0x9592675B, (q31_t)0xB936BFA3,
	(q31_t)0x955AAE17, (q31_t)0xB98A97D8, (q31_t)0x9523369B,
	(q31_t)0xB9DE9B83, (q31_t)0x94EC010B, (q31_t)0xBA32CA70,
	(q31_t)0x94B50D87, (q31_t)0xBA87246C, (q31_t)0x947E5C32,
	(q31_t)0xBADBA943, (q31_t)0x9447ED2F, (q31_t)0xBB3058C0,
	(q31_t)0x9411C09D, (q31_t)0xBB8532AF, (q31_t)0x93DBD69F,
	(q31_t)0xBBDA36DC, (q31_t)0x93A62F56, (q31_t)0xBC2F6513,
	(q31_t)0x9370CAE4, (q31_t)0xBC84BD1E, (q31_t)0x933BA968,
	(q31_t)0xBCDA3ECA, (q31_t)0x9306CB04, (q31_t)0xBD2FE9E1,
	(q31_t)0x92D22FD8, (q31_t)0xBD85BE2F, (q31_t)0x929DD805,
	(q31_t)0xBDDBBB7F, (q31_t)0x9269C3AC, (q31_t)0xBE31E19B,
	(q31_t)0x9235F2EB, (q31_t)0xBE88304F, (q31_t)0x920265E4,
	(q31_t)0xBEDEA765, (q31_t)0x91CF1CB6, (q31_t)0xBF3546A8,
	(q31_t)0x919C1780, (q31_t)0xBF8C0DE2, (q31_t)0x91695663,
	(q31_t)0xBFE2FCDF, (q31_t)0x9136D97D, (q31_t)0xC03A1368,
	(q31_t)0x9104A0ED, (q31_t)0xC0915147, (q31_t)0x90D2ACD3,
	(q31_t)0xC0E8B648, (q31_t)0x90A0FD4E, (q31_t)0xC1404233,
	(q31_t)0x906F927B, (q31_t)0xC197F4D3, (q31_t)0x903E6C7A,
	(q31_t)0xC1EFCDF2, (q31_t)0x900D8B69, (q31_t)0xC247CD5A,
	(q31_t)0x8FDCEF66, (q31_t)0xC29FF2D4, (q31_t)0x8FAC988E,
	(q31_t)0xC2F83E2A, (q31_t)0x8F7C8701, (q31_t)0xC350AF25,
	(q31_t)0x8F4CBADB, (q31_t)0xC3A9458F, (q31_t)0x8F1D343A,
	(q31_t)0xC4020132, (q31_t)0x8EEDF33B, (q31_t)0xC45AE1D7,
	(q31_t)0x8EBEF7FB, (q31_t)0xC4B3E746, (q31_t)0x8E904298,
	(q31_t)0xC50D1148, (q31_t)0x8E61D32D, (q31_t)0xC5665FA8,
	(q31_t)0x8E33A9D9, (q31_t)0xC5BFD22E, (q31_t)0x8E05C6B7,
	(q31_t)0xC61968A2, (q31_t)0x8DD829E4, (q31_t)0xC67322CD,
	(q31_t)0x8DAAD37B, (q31_t)0xC6CD0079, (q31_t)0x8D7DC399,
	(q31_t)0xC727016C, (q31_t)0x8D50FA59, (q31_t)0xC7812571,
	(q31_t)0x8D2477D8, (q31_t)0xC7DB6C50, (q31_t)0x8CF83C30,
	(q31_t)0xC835D5D0, (q31_t)0x8CCC477D, (q31_t)0xC89061BA,
	(q31_t)0x8CA099D9, (q31_t)0xC8EB0FD6, (q31_t)0x8C753361,
	(q31_t)0xC945DFEC, (q31_t)0x8C4A142F, (q31_t)0xC9A0D1C4,
	(q31_t)0x8C1F3C5C, (q31_t)0xC9FBE527, (q31_t)0x8BF4AC05,
	(q31_t)0xCA5719DB, (q31_t)0x8BCA6342, (q31_t)0xCAB26FA9,
	(q31_t)0x8BA0622F, (q31_t)0xCB0DE658, (q31_t)0x8B76A8E4,
	(q31_t)0xCB697DB0, (q31_t)0x8B4D377C, (q31_t)0xCBC53578,
	(q31_t)0x8B240E10, (q31_t)0xCC210D78, (q31_t)0x8AFB2CBA,
	(q31_t)0xCC7D0577, (q31_t)0x8AD29393, (q31_t)0xCCD91D3D,
	(q31_t)0x8AAA42B4, (q31_t)0xCD355490, (q31_t)0x8A823A35,
	(q31_t)0xCD91AB38, (q31_t)0x8A5A7A30, (q31_t)0xCDEE20FC,
	(q31_t)0x8A3302BD, (q31_t)0xCE4AB5A2, (q31_t)0x8A0BD3F5,
	(q31_t)0xCEA768F2, (q31_t)0x89E4EDEE, (q31_t)0xCF043AB2,
	(q31_t)0x89BE50C3, (q31_t)0xCF612AAA, (q31_t)0x8997FC89,
	(q31_t)0xCFBE389F, (q31_t)0x8971F15A, (q31_t)0xD01B6459,
	(q31_t)0x894C2F4C, (q31_t)0xD078AD9D, (q31_t)0x8926B677,
	(q31_t)0xD0D61433, (q31_t)0x890186F1, (q31_t)0xD13397E1,
	(q31_t)0x88DCA0D3, (q31_t)0xD191386D, (q31_t)0x88B80431,
	(q31_t)0xD1EEF59E, (q31_t)0x8893B124, (q31_t)0xD24CCF38,
	(q31_t)0x886FA7C2, (q31_t)0xD2AAC504, (q31_t)0x884BE820,
	(q31_t)0xD308D6C6, (q31_t)0x88287255, (q31_t)0xD3670445,
	(q31_t)0x88054677, (q31_t)0xD3C54D46, (q31_t)0x87E2649B,
	(q31_t)0xD423B190, (q31_t)0x87BFCCD7, (q31_t)0xD48230E8,
	(q31_t)0x879D7F40, (q31_t)0xD4E0CB14, (q31_t)0x877B7BEC,
	(q31_t)0xD53F7FDA, (q31_t)0x8759C2EF, (q31_t)0xD59E4EFE,
	(q31_t)0x8738545E, (q31_t)0xD5FD3847, (q31_t)0x8717304E,
	(q31_t)0xD65C3B7B, (q31_t)0x86F656D3, (q31_t)0xD6BB585D,
	(q31_t)0x86D5C802, (q31_t)0xD71A8EB5, (q31_t)0x86B583EE,
	(q31_t)0xD779DE46, (q31_t)0x86958AAB, (q31_t)0xD7D946D7,
	(q31_t)0x8675DC4E, (q31_t)0xD838C82D, (q31_t)0x865678EA,
	(q31_t)0xD898620C, (q31_t)0x86376092, (q31_t)0xD8F81439,
	(q31_t)0x86189359, (q31_t)0xD957DE7A, (q31_t)0x85FA1152,
	(q31_t)0xD9B7C093, (q31_t)0x85DBDA91, (q31_t)0xDA17BA4A,
	(q31_t)0x85BDEF27, (q31_t)0xDA77CB62, (q31_t)0x85A04F28,
	(q31_t)0xDAD7F3A2, (q31_t)0x8582FAA4, (q31_t)0xDB3832CD,
	(q31_t)0x8565F1B0, (q31_t)0xDB9888A8, (q31_t)0x8549345C,
	(q31_t)0xDBF8F4F8, (q31_t)0x852CC2BA, (q31_t)0xDC597781,
	(q31_t)0x85109CDC, (q31_t)0xDCBA1008, (q31_t)0x84F4C2D3,
	(q31_t)0xDD1ABE51, (q31_t)0x84D934B0, (q31_t)0xDD7B8220,
	(q31_t)0x84BDF285, (q31_t)0xDDDC5B3A, (q31_t)0x84A2FC62,
	(q31_t)0xDE3D4963, (q31_t)0x84885257, (q31_t)0xDE9E4C60,
	(q31_t)0x846DF476, (q31_t)0xDEFF63F4, (q31_t)0x8453E2CE,
	(q31_t)0xDF608FE3, (q31_t)0x843A1D70, (q31_t)0xDFC1CFF2,
	(q31_t)0x8420A46B, (q31_t)0xE02323E5, (q31_t)0x840777CF,
	(q31_t)0xE0848B7F, (q31_t)0x83EE97AC, (q31_t)0xE0E60684,
	(q31_t)0x83D60411, (q31_t)0xE14794B9, (q31_t)0x83BDBD0D,
	(q31_t)0xE1A935E1, (q31_t)0x83A5C2B0, (q31_t)0xE20AE9C1,
	(q31_t)0x838E1507, (q31_t)0xE26CB01A, (q31_t)0x8376B422,
	(q31_t)0xE2CE88B2, (q31_t)0x835FA00E, (q31_t)0xE330734C,
	(q31_t)0x8348D8DB, (q31_t)0xE3926FAC, (q31_t)0x83325E97,
	(q31_t)0xE3F47D95, (q31_t)0x831C314E, (q31_t)0xE4569CCB,
	(q31_t)0x8306510F, (q31_t)0xE4B8CD10, (q31_t)0x82F0BDE8,
	(q31_t)0xE51B0E2A, (q31_t)0x82DB77E5, (q31_t)0xE57D5FDA,
	(q31_t)0x82C67F13, (q31_t)0xE5DFC1E4, (q31_t)0x82B1D381,
	(q31_t)0xE642340D, (q31_t)0x829D753A, (q31_t)0xE6A4B616,
	(q31_t)0x8289644A, (q31_t)0xE70747C3, (q31_t)0x8275A0C0,
	(q31_t)0xE769E8D8, (q31_t)0x82622AA5, (q31_t)0xE7CC9917,
	(q31_t)0x824F0208, (q31_t)0xE82F5844, (q31_t)0x823C26F2,
	(q31_t)0xE8922621, (q31_t)0x82299971, (q31_t)0xE8F50273,
	(q31_t)0x8217598F, (q31_t)0xE957ECFB, (q31_t)0x82056758,
	(q31_t)0xE9BAE57C, (q31_t)0x81F3C2D7, (q31_t)0xEA1DEBBB,
	(q31_t)0x81E26C16, (q31_t)0xEA80FF79, (q31_t)0x81D16320,
	(q31_t)0xEAE4207A, (q31_t)0x81C0A801, (q31_t)0xEB474E80,
	(q31_t)0x81B03AC1, (q31_t)0xEBAA894E, (q31_t)0x81A01B6C,
	(q31_t)0xEC0DD0A8, (q31_t)0x81904A0C, (q31_t)0xEC71244F,
	(q31_t)0x8180C6A9, (q31_t)0xECD48406, (q31_t)0x8171914E,
	(q31_t)0xED37EF91, (q31_t)0x8162AA03, (q31_t)0xED9B66B2,
	(q31_t)0x815410D3, (q31_t)0xEDFEE92B, (q31_t)0x8145C5C6,
	(q31_t)0xEE6276BF, (q31_t)0x8137C8E6, (q31_t)0xEEC60F31,
	(q31_t)0x812A1A39, (q31_t)0xEF29B243, (q31_t)0x811CB9CA,
	(q31_t)0xEF8D5FB8, (q31_t)0x810FA7A0, (q31_t)0xEFF11752,
	(q31_t)0x8102E3C3, (q31_t)0xF054D8D4, (q31_t)0x80F66E3C,
	(q31_t)0xF0B8A401, (q31_t)0x80EA4712, (q31_t)0xF11C789A,
	(q31_t)0x80DE6E4C, (q31_t)0xF1805662, (q31_t)0x80D2E3F1,
	(q31_t)0xF1E43D1C, (q31_t)0x80C7A80A, (q31_t)0xF2482C89,
	(q31_t)0x80BCBA9C, (q31_t)0xF2AC246D, (q31_t)0x80B21BAF,
	(q31_t)0xF310248A, (q31_t)0x80A7CB49, (q31_t)0xF3742CA1,
	(q31_t)0x809DC970, (q31_t)0xF3D83C76, (q31_t)0x8094162B,
	(q31_t)0xF43C53CA, (q31_t)0x808AB180, (q31_t)0xF4A07260,
	(q31_t)0x80819B74, (q31_t)0xF50497FA, (q31_t)0x8078D40D,
	(q31_t)0xF568C45A, (q31_t)0x80705B50, (q31_t)0xF5CCF743,
	(q31_t)0x80683143, (q31_t)0xF6313076, (q31_t)0x806055EA,
	(q31_t)0xF6956FB6, (q31_t)0x8058C94C, (q31_t)0xF6F9B4C5,
	(q31_t)0x80518B6B, (q31_t)0xF75DFF65, (q31_t)0x804A9C4D,
	(q31_t)0xF7C24F58, (q31_t)0x8043FBF6, (q31_t)0xF826A461,
	(q31_t)0x803DAA69, (q31_t)0xF88AFE41, (q31_t)0x8037A7AC,
	(q31_t)0xF8EF5CBB, (q31_t)0x8031F3C1, (q31_t)0xF953BF90,
	(q31_t)0x802C8EAD, (q31_t)0xF9B82683, (q31_t)0x80277872,
	(q31_t)0xFA1C9156, (q31_t)0x8022B113, (q31_t)0xFA80FFCB,
	(q31_t)0x801E3894, (q31_t)0xFAE571A4, (q31_t)0x801A0EF7,
	(q31_t)0xFB49E6A2, (q31_t)0x80163440, (q31_t)0xFBAE5E89,
	(q31_t)0x8012A86F, (q31_t)0xFC12D919, (q31_t)0x800F6B88,
	(q31_t)0xFC775616, (q31_t)0x800C7D8C, (q31_t)0xFCDBD541,
	(q31_t)0x8009DE7D, (q31_t)0xFD40565B, (q31_t)0x80078E5E,
	(q31_t)0xFDA4D928, (q31_t)0x80058D2E, (q31_t)0xFE095D69,
	(q31_t)0x8003DAF0, (q31_t)0xFE6DE2E0, (q31_t)0x800277A5,
	(q31_t)0xFED2694F, (q31_t)0x8001634D, (q31_t)0xFF36F078,
	(q31_t)0x80009DE9, (q31_t)0xFF9B781D, (q31_t)0x8000277A
};

const q31_t twiddleCoef_64_q31[96] = {
    -2147483648, 0,
    2137142927, -210490206,
    2106220351, -418953276,
    2055013723, -623381597,
    1984016188, -821806413,
    1893911494, -1012316784,
    1785567396, -1193077990,
    1660027308, -1362349204,
    1518500249, -1518500249,
    1362349204, -1660027308,
    1193077990, -1785567396,
    1012316784, -1893911494,
    821806413, -1984016188,
    623381597, -2055013723,
    418953276, -2106220351,
    210490206, -2137142927,
    0, -2147483648,
    -210490206, -2137142927,
    -418953276, -2106220351,
    -623381597, -2055013723,
    -821806413, -1984016188,
    -1012316784, -1893911494,
    -1193077990, -1785567396,
    -1362349204, -1660027308,
    -1518500249, -1518500249,
    -1660027308, -1362349204,
    -1785567396, -1193077990,
    -1893911494, -1012316784,
    -1984016188, -821806413,
    -2055013723, -623381597,
    -2106220351, -418953276,
    -2137142927, -210490206,
    -2147483648, 0,
    -2137142927, 210490206,
    -2106220351, 418953276,
    -2055013723, 623381597,
    -1984016188, 821806413,
    -1893911494, 1012316784,
    -1785567396, 1193077990,
    -1660027308, 1362349204,
    -1518500249, 1518500249,
    -1362349204, 1660027308,
    -1193077990, 1785567396,
    -1012316784, 1893911494,
    -821806413, 1984016188,
    -623381597, 2055013723,
    -418953276, 2106220351,
    -210490206, 2137142927,
    0, -2147483648,
    210490206, 2137142927,
    418953276, 2106220351,
    623381597, 2055013723,
    821806413, 1984016188,
    1012316784, 1893911494,
    1193077990, 1785567396,
    1362349204, 1660027308,
    1518500249, 1518500249,
    1660027308, 1362349204,
    1785567396, 1193077990,
    1893911494, 1012316784,
    1984016188, 821806413,
    2055013723, 623381597,
    2106220351, 418953276,
    2137142927, 210490206
};

const q31_t twiddleCoef_16_q31[24] = {
    (q31_t)0x7FFFFFFF, (q31_t)0x00000000,
    (q31_t)0x7641AF3C, (q31_t)0x30FBC54D,
    (q31_t)0x5A82799A, (q31_t)0x5A82799A,
    (q31_t)0x30FBC54D, (q31_t)0x7641AF3C,
    (q31_t)0x00000000, (q31_t)0x7FFFFFFF,
    (q31_t)0xCF043AB2, (q31_t)0x7641AF3C,
    (q31_t)0xA57D8666, (q31_t)0x5A82799A,
    (q31_t)0x89BE50C3, (q31_t)0x30FBC54D,
    (q31_t)0x80000000, (q31_t)0x00000000,
    (q31_t)0x89BE50C3, (q31_t)0xCF043AB2,
    (q31_t)0xA57D8666, (q31_t)0xA57D8666,
    (q31_t)0xCF043AB2, (q31_t)0x89BE50C3
};

const q31_t twiddleCoef_32_q31[48] = {
    (q31_t)0x7FFFFFFF, (q31_t)0x00000000,
    (q31_t)0x7D8A5F3F, (q31_t)0x18F8B83C,
    (q31_t)0x7641AF3C, (q31_t)0x30FBC54D,
    (q31_t)0x6A6D98A4, (q31_t)0x471CECE6,
    (q31_t)0x5A82799A, (q31_t)0x5A82799A,
    (q31_t)0x471CECE6, (q31_t)0x6A6D98A4,
    (q31_t)0x30FBC54D, (q31_t)0x7641AF3C,
    (q31_t)0x18F8B83C, (q31_t)0x7D8A5F3F,
    (q31_t)0x00000000, (q31_t)0x7FFFFFFF,
    (q31_t)0xE70747C3, (q31_t)0x7D8A5F3F,
    (q31_t)0xCF043AB2, (q31_t)0x7641AF3C,
    (q31_t)0xB8E31319, (q31_t)0x6A6D98A4,
    (q31_t)0xA57D8666, (q31_t)0x5A82799A,
    (q31_t)0x9592675B, (q31_t)0x471CECE6,
    (q31_t)0x89BE50C3, (q31_t)0x30FBC54D,
    (q31_t)0x8275A0C0, (q31_t)0x18F8B83C,
    (q31_t)0x80000000, (q31_t)0x00000000,
    (q31_t)0x8275A0C0, (q31_t)0xE70747C3,
    (q31_t)0x89BE50C3, (q31_t)0xCF043AB2,
    (q31_t)0x9592675B, (q31_t)0xB8E31319,
    (q31_t)0xA57D8666, (q31_t)0xA57D8666,
    (q31_t)0xB8E31319, (q31_t)0x9592675B,
    (q31_t)0xCF043AB2, (q31_t)0x89BE50C3,
    (q31_t)0xE70747C3, (q31_t)0x8275A0C0
};


// **完整的 64 点 Bit Reverse 索引表**
/*
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
*/
const uint16_t bitRevIndexTable_64[56] = {
    8,256, 16,128, 24,384, 32,64, 40,320, 48,192, 56,448, 72,288, 80,160, 88,416, 104,352,
   112,224, 120,480, 136,272, 152,400, 168,336, 176,208, 184,464, 200,304, 216,432,
   232,368, 248,496, 280,392, 296,328, 312,456, 344,424, 376,488, 440,472
 };

const uint16_t bitRevIndexTable_128[112] =
{
   /* 4x2, size 112 */
   8,512, 16,256, 24,768, 32,128, 40,640, 48,384, 56,896, 72,576, 80,320, 88,832, 96,192,
   104,704, 112,448, 120,960, 136,544, 144,288, 152,800, 168,672, 176,416, 184,928, 200,608,
   208,352, 216,864, 232,736, 240,480, 248,992, 264,528, 280,784, 296,656, 304,400, 312,912,
   328,592, 344,848, 360,720, 368,464, 376,976, 392,560, 408,816, 424,688, 440,944, 456,624,
   472,880, 488,752, 504,1008, 536,776, 552,648, 568,904, 600,840, 616,712, 632,968,
   664,808, 696,936, 728,872, 760,1000, 824,920, 888,984
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
    .pTwiddle = twiddleCoef_64_q31,	// todo
    .bitRevLength = REV_LEN,// 112,  // todo// **64 点 FFT 的 Bit Reverse 长度**
    .pBitRevTable = bitRevIndexTable_64	// todo
};

const arm_cfft_instance_q31 my_arm_cfft_sR_q31_len128 = {
    .fftLen = FFT_LEN,
    .pTwiddle = twiddleCoef_128_q31,	// todo
    .bitRevLength = REV_LEN,// 112,  // todo// **64 点 FFT 的 Bit Reverse 长度**
    .pBitRevTable = bitRevIndexTable_128	// todo
};

const arm_cfft_instance_q31 my_arm_cfft_sR_q31_len16 = {
    .fftLen = FFT_LEN,
    .pTwiddle = twiddleCoef_16_q31,	// todo
    .bitRevLength = REV_LEN,// 112,  // todo// **64 点 FFT 的 Bit Reverse 长度**
    .pBitRevTable = bitRevIndexTable_128	// todo
};

const arm_cfft_instance_q31 my_arm_cfft_sR_q31_len256 = {
    .fftLen = FFT_LEN,
    .pTwiddle = twiddleCoef_256_q31,	// todo
    //.bitRevLength = REV_LEN,// 112,  // todo// **64 点 FFT 的 Bit Reverse 长度**
    //.pBitRevTable = bitRevIndexTable_128	// todo
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
    const arm_cfft_instance_q31 *S = &my_arm_cfft_sR_q31_len128;

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

    //pSrc[0] = -1225420319;
    //pSrc[2048] = 28500178;
    //pSrc[1] = -1491784357;
    //pSrc[2049] = -161989045;
	// main
    arm_cfft_q31(S, pSrc, 1, 1);

    // **打开文件**
    FILE *file_input_dec   = fopen("ifft128r/fft_input_decimal.txt", "w");
    FILE *file_input_bin   = fopen("ifft128r/fft_input_binary.txt", "w");
    FILE *file_output_dec  = fopen("ifft128r/fft_output_decimal.txt", "w");
    FILE *file_output_bin  = fopen("ifft128r/fft_output_binary.txt", "w");
    FILE *file_twiddle_dec = fopen("ifft128r/fft_twiddle_decimal.txt", "w");
    FILE *file_twiddle_bin = fopen("ifft128r/fft_twiddle_binary.txt", "w");

    if (!file_input_dec || !file_input_bin || !file_output_dec || !file_output_bin || !file_twiddle_dec || !file_twiddle_bin) {
        printf("Error opening file for writing.\n");
        return;
    }

    char binary_str[33];

    // **写入输入数据**
	for (int i = 0; i < SRC_BASE; i++) {
    	fprintf(file_input_dec, "%d\n", 0);  
    	int_to_binary(0, binary_str);
    	fprintf(file_input_bin, "%s\n", binary_str);
	}
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
        fprintf(file_output_dec, "%d\n", pSrc[2 * i + DEST_BASE]);  // 实部
        fprintf(file_output_dec, "%d\n", pSrc[2 * i + 1 + DEST_BASE]);  // 虚部

        int_to_binary(pSrc[2 * i + DEST_BASE], binary_str);
        fprintf(file_output_bin, "%s\n", binary_str);
        int_to_binary(pSrc[2 * i + 1 + DEST_BASE], binary_str);
        fprintf(file_output_bin, "%s\n", binary_str);
    }

    // **写入 Twiddle 因子数据**
    for (int i = 0; i < TWID_LEN*2; i += 2) {
        fprintf(file_twiddle_dec, "%d\n", twiddleCoef_128_q31[i]);  // 实部
        fprintf(file_twiddle_dec, "%d\n", twiddleCoef_128_q31[i + 1]);  // 虚部

        int_to_binary(twiddleCoef_128_q31[i], binary_str);
        fprintf(file_twiddle_bin, "%s\n", binary_str);
        int_to_binary(twiddleCoef_128_q31[i + 1], binary_str);
        fprintf(file_twiddle_bin, "%s\n", binary_str);
    }
    for (int i = 0; i < REV_LEN; i += 1) {
        fprintf(file_twiddle_dec, "%d\n", bitRevIndexTable_128[i]);  
        int_to_binary(bitRevIndexTable_128[i], binary_str);
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
    //int16_t x_tf2;
    //uint16_t shift;
    //x_tf2 = 1025;
    //shift = 6;
    //uint8_t idx = (uint8_t)(x_tf2 >> shift);
    //printf("idx: %d\n", idx);
    return 0;
}
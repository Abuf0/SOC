
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
      //printf("Before twid : ia1 = %d\n",ia1);
      ia1 = ia1 + twidCoefModifier;
      //printf("After twid : ia1 = %d\n",ia1);
        printf("TWID : %d\n", twidCoefModifier);

      /*  Updating input index */
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
        //printf("Before twid : ia1 = %d\n",ia1);
        ia1 = ia1 + twidCoefModifier;
        //printf("After twid : ia1 = %d\n",ia1);
        printf("TWID : %d\n", twidCoefModifier);
  
        for (i0 = j; i0 < fftLen; i0 += n1)
        {
          /*  index calculation for the input as, */
          /*  pSrc[i0 + 0], pSrc[i0 + fftLen/4], pSrc[i0 + fftLen/2u], pSrc[i0 + 3fftLen/4] */
          i1 = i0 + n2;
          i2 = i1 + n2;
          i3 = i2 + n2;
          printf("data: pSrc[%d], pSrc[%d], pSrc[%d], pSrc[%d]\n",i0, i1, i2, i3);
          
  
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
        printf("cosVal is %d\n",ia);
        cosVal = pCoef[2*ia];
        sinVal = pCoef[2*ia + 1];
        ia++;
        
        l = i + n2;
        printf("xt = (pSrc[2 * %d] >> 2) - (pSrc[2 * %d] >> 2)\n",i,l);
        xt = (pSrc[2 * i] >> 2) - (pSrc[2 * l] >> 2);
        pSrc[2 * i] = (pSrc[2 * i] >> 2) + (pSrc[2 * l] >> 2);

        printf("yt = (pSrc[2 * %d + 1] >> 2) - (pSrc[2 * %d + 1] >> 2)\n",i,l);
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
    printf("bitreversal, len = %d\n",bitRevLen);
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

void main(){
    uint32_t fftLen = 128;
    arm_cfft_instance_q31 S;
    arm_cfft_init_q31(&S, fftLen);
    q31_t p1[2*fftLen];
    for(int i=0;i<fftLen;i++){
        p1[2*i] = 1;
        p1[2*i+1] = 1;
    }
    uint32_t twidCoefModifier = 1;
    uint8_t ifftFlag = 0;
    uint8_t bitReverseFlag = 1;
    arm_cfft_q31(&S,p1,ifftFlag,bitReverseFlag);
}
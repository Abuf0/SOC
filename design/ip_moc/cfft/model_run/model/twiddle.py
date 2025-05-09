# -*- coding: utf-8 -*-
import numpy as np

def generate_twiddle_factors(fft_size):
    """
    计算指定点数的 FFT Twiddle 因子表 (Q31 格式)
    
    :param fft_size: FFT 的点数 (必须是 2 的幂，如 128, 256, 512, 1024)
    :return: 以 C 语言格式返回 twiddle 因子数组
    """
    # 计算 Twiddle 因子 (单位根 e^(-j*2*pi*k/N) * 2^31) 并转换为 Q31 格式
    twiddle_factors = np.exp(-2j * np.pi * np.arange(fft_size) / fft_size) * (2**31)

    # 提取实部和虚部，并转换为 Q31 格式（int32）
    twiddle_factors_real = twiddle_factors.real.astype(np.int32)
    twiddle_factors_imag = twiddle_factors.imag.astype(np.int32)

    # 生成 C 语言数组格式
    twiddle_c_array = ",\n".join([f"    {r}, {i}" for r, i in zip(twiddle_factors_real, twiddle_factors_imag)])
    twiddle_c_code = f"const q31_t twiddleCoef_{fft_size}_q31[{fft_size * 2}] = {{\n{twiddle_c_array}\n}};"

    return twiddle_c_code

# **示例：计算 512 点 FFT 的 Twiddle 因子**
fft_size = 64  # 你可以改成 128, 256, 1024, 2048
twiddle_factors_code = generate_twiddle_factors(fft_size)
print(twiddle_factors_code)  # 你可以保存为 C 文件

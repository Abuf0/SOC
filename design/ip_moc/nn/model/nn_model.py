import numpy as np
def conv(input_data, kernel, padding=0, stride=1):
    batch_size, in_height, in_width, in_channels = input_data.shape
    num_kernels, kernel_height, kernel_width, in_channels = kernel.shape
    input_padded = np.pad(input_data, ((0, 0), (padding, padding), (padding, padding), (0, 0)), mode='constant')
    out_height = (in_height + 2 * padding - kernel_height) // stride + 1
    out_width = (in_width + 2 * padding - kernel_width) // stride + 1
    output = np.zeros((batch_size, out_height, out_width, num_kernels), dtype=np.int32)
    for b in range(batch_size):
        for h in range(out_height):
            for w in range(out_width):
                for k in range(num_kernels):
                    h_start = h * stride
                    w_start = w * stride
                    h_end = h_start + kernel_height
                    w_end = w_start + kernel_width
                    if h_end <= input_padded.shape[1] and w_end <= input_padded.shape[2]:
                        patch = input_padded[b, h_start:h_end, w_start:w_end, :]
                        output[b, h, w, k] = np.sum(patch * kernel[k, :, :, :])
    return output

# 配置参数
batch_size = 1
in_height = 8
in_width = 8
in_channels = 64
num_kernels = 128
kernel_height = 3
kernel_width = 3
padding = 0
stride = 1

# 设置随机种子以实现伪随机
np.random.seed(42)

# 生成伪随机输入数据和卷积核，并转换为 int8 类型，按照 HWC 存放
input_data = np.random.randint(-128, 127, size=(batch_size, in_height, in_width, in_channels), dtype=np.int8)
# 按照 NHWC 顺序生成卷积核
kernel = np.random.randint(-128, 127, size=(num_kernels, kernel_height, kernel_width, in_channels), dtype=np.int8)

# 进行卷积操作
output = conv(input_data, kernel, padding, stride)

# 按照 HWC 顺序输出输入数据到文件
try:
    with open('input_data_dec.txt', 'w') as f:
        for b in range(batch_size):
            for h in range(in_height):
                for w in range(in_width):
                    for c in range(in_channels):
                        f.write(str(input_data[b, h, w, c]) + '\n')
    print("输入数据已成功写入 input_data_dec.txt 文件。")
except Exception as e:
    print(f"写入输入数据文件时出错: {type(e).__name__} - {e}")

# 按照 HWC 顺序输出权重数据到文件

try:
    with open('kernel_data_dec.txt', 'w') as f:
        for k in range(num_kernels):
            f.write('K num:' + str(k) + '\n')
            for kh in range(kernel_height):
                for kw in range(kernel_width):
                    for c in range(in_channels):
                        f.write(str(kernel[k, kh, kw, c]) + '\n')
    print("权重数据已成功写入 kernel_data_dec.txt 文件。")
except Exception as e:
    print(f"写入权重数据文件时出错: {type(e).__name__} - {e}")

# 将输出数据写入文件
try:
    with open('output_data_dec.txt', 'w') as f:
        f.write(str(output))
except Exception as e:
    print(f"写入输出数据文件时出错: {e}")

def convert_to_binary(data, file_path):
    binary_buffer = []
    try:
        with open(file_path, 'w') as f:
            for element in data.flat:
                # 将 int8 数据转换为 8 位二进制字符串
                binary_str = '{:08b}'.format(element)
                if element == -128:
                    binary_str = binary_str.replace('-', '')
                else:
                    binary_str = binary_str.replace('-', '1')
                binary_buffer.append(binary_str)
                if len(binary_buffer) == 32:
                    line = ''.join(binary_buffer)
                    f.write(line + '\n')
                    binary_buffer = []
            if binary_buffer:
                line = ''.join(binary_buffer).ljust(32 * 8, '0')
                f.write(line + '\n')
        print(f"{file_path} 文件写入成功。")
    except Exception as e:
        print(f"写入 {file_path} 文件时出错: {type(e).__name__} - {e}")


# 按照 HWC 顺序将输入数据转换为二进制并输出到文件
convert_to_binary(input_data, 'input_data_bin.txt')

# 按照 HWC 顺序将权重数据转换为二进制并输出到文件
convert_to_binary(kernel, 'kernel_data_bin.txt')

# 进行卷积操作
output = conv(input_data, kernel, padding, stride)

# 按照 HWC 顺序将输出数据转换为二进制并输出到文件
convert_to_binary(output.astype(np.int8), 'output_data_bin.txt')
    
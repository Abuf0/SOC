import os
import csv
import pandas as pd
import torch
from tqdm import tqdm
import numpy as np
from matplotlib import pyplot as print_log

plt.rcParams['font.family'] = ['xx', 'yy', 'sans-serif']
plt.rcParams['axes.unicode_minus'] = False  # 显示负号
labelDict_heavyLight = {0: '抬起', 1: '轻触', 2: '重按'}
labelDict_downUp = {0: '抬起', 1: '按压'}

## 浮点转整数
def findN_floor(x_f):
    x = int(x_f)
    x |= x >> 1
    x |= x >> 2
    x |= x >> 4
    x |= x >> 8
    x |= x >> 16
    if (x+1) >> 1 == int(x_f):
        return float(x_f)
    else:
        return float((x+1) >> 1)

def ReLU(x):
    x = np.where(x < 0, 0, x)
    return x

def overflow_detect(data_name, data, bit_num, print_log=True):
    val_max = 2**(bit_num - 1) - 1
    val_min = -2**(bit_num - 1)
    if np.sum(data < val_min) + np.sum(data > val_max) != 0:
        if print_log:
            printf('\033[1;31m %s 数据溢出 --> int%d \033[0m' % (data_name, bit_num), data.reshape(1, data.size))
        data = np.clip(data, val_min, val_max)
        if print_log:
            printf('\033[1;31m %s clip --> int%d \033[0m' % (data_name, bit_num), data.reshape(1, data.size))
    return data

class dataProcess:
    def __init__(self, data_root, roi_offset):
        """
        原始采集数据 -> 计算AMP -> 采样 -> 形成均值序列
        @param data_root:
        @param roi_offset: 数据有效起始行
        """
        self.data_root = data_root
        self.roi_offset = roi_offset
        self.phase_cnt = 4
        self.col = 9 
        self.s_row = 4
        self.select_row = 4

    def data_convert_file(self):
        """
        包含多帧数据的单个文件读取方式
        """
        data = pd.read_csv(self.data_root, header=None)
        data_2 = data.dropna(how='any')
        data_2.reset_index(drop=True, inplace=True) # 去除空行并更新行号
        frame_cnt = int(len(data_2) // 4)
        SeqList = []
        for i in tqdm(range(frame_cnt)):
            rawdata = np.array(data_2.iloc[i*4:(i+1)*4, :])
            ## IQ计算 + AMP计算
            roi_amp = self.convert_chipPCTool_data_to_Amp_single_frame_data_25(rawdata)
            # 采样ROI -> 取均值
            sample = self.single_frame_sample(roi_amp, 0, 25, 1)
            SeqList.append(np.mean(sample).astype(np.int16))
        return SeqList

    def convert_chipPCTool_data_to_Amp_single_frame_data_25(self, rawdata):
        phase_data = rawdata.reshape(self.phase_cnt, 1, 25)

        I = abs(phase_data[0] // 2 - phase_data[2] // 2) # 11bit
        Q = abs(phase_data[1] // 2 - phase_data[3] // 2) # 11bit
        amp = np.sqrt(Q * Q + I * I).astype(np.int16)   # amp结果为11bit

        roi_amp = amp
        return roi_amp

    def single_frame_sample(self, data, col_start, col_end, sample_gap):
        sample_data = data[:, col_start:col_end:sample_gap]
        return sample_data


def press_detect_RNN_quantRevert(self, inpu_data, h_0):
    """
    模型计算流程，输入归一化->（up/down）->轻重按
    @param input_data
    @return : 轻重按，按压或抬起
    """

    # 1. 输入数据归一化，2N归一化 or 2N校准归一化
    x_scale = 256 / self.input_quant_scale
    input_data = input.astype(np.int32)
    range_N = int(findN_floor(np.ptp(input_data)))
    range_N = 1 if range_N == 0 else range_N # 避免除以0
    mean_val = np.mean(input_data).asype(np.int32) # 11bit
    input_diff = (input_data - mean_val) # 11bit

    input_scale = input_diff * x_scale # 16bit 若溢出按饱和
    input_scale = np.clip(input_scale, np.clip(np.int16).min, np.iinfo(np.int16).max)

    input_norm = input_scale // range_N # 8bit
    input_norm = np.clip(input_norm, np.iinfo(np.int8).min, np.iinfo(np.int8).max) # 若溢出按饱和 【-128， 127】

    # 2. RNN输出网络结果0-up，1-down，2-maintain
    fc_upDown_weight = self.fc_upDown_weight
    fc_upDown_bias = self.fc_bias 
    # 2.1 两层L0 --> L1的NN计算 @ RNN_QuantRevert
    out_RNN, h_0 = self.RNN_QuantRevert(input_norm, h_0)
    # 2.2 FC层
    weight_scale = 256 // self.fc_weight_quant_scale
    out_updown_w = np.matmul(out_RNN, fc_upDown_weight.T) # 16bit
    out_updown_w = overflow_detect('out_updown_w', out_updown_w, 16, self.print_log)
    out_updown_w = out_updown_w // weight_scale
    out_updown_w = overflow_detect('out_updown_w_scale', out_updown_w, 8, self.print_log)
    out_updown_w = out_updown_w + fc_upDown_bias.T # 16bit
    out_updown_w = overflow_detect('out_updown', out_updown, 8, self.print_log)
    # ==> 判断结果
    res_upDown = np.argmax(out_updown)

    return res_upDown, h_0

def press_detect(self, input_data, h_0):
    res_upDown, h_0 = self.press_detect_RNN_quantRevert(input_data, h_0)
    return res_upDown, h_0

def RunDemo(param_file, data_root, roi_offset, MemSeqLen=5, PADDING_LEN_MARK=4, decision_mode=0, downMemCount=5, upMemCount=3):
    """
    FDT检测方案流程：加载模型参数->加载数据->FDT检测
    @param upMemCount: decision_mode=1时，从down到up的切换需要连续upMemCount个点up才能up
    @param downMemCount: decision_mode=1时，从up到down的切换需要连续downMemCount个点up才能up
    @param param_file：参数文件
    @param data_root： 原始数据文件路径
    @param roi_offset：有效数据偏移位
    @param decision_mode：决策方式
    @param MemSeqLen：MemSeq长度配置
    @param PADDING_LEN_MASK：数据进行RNN计算的最小数据长度，可配置[4,8,12,16]
    @return：None

    """
    print('============>>>>>>>>>>>> Loading param'
            '%s || c_in->%d || c_out->%d || hidden_size->%d || num_layer->%d ||' % get_model_set(param_file))
    version, c_in, c_out, hidden_size, num_layer = get_model_set(param_file)
    h_0 = np.zeros((num_layer, hidden_size))
    demo_0 = pressDetectDemo(param_file, mode=0)

    print('============>>>>>>>>>>>> Loading data')
    data_process = dataProcess(data_root, roi_offset)
    input_seq = data_process.data_convert_file()

    print('============>>>>>>>>>>>> Testing')
    frame_cnt = len(input_seq)
    MemSeq = [0] * MemSeqLen
    PredRes = []
    downCount = 0
    upCount = 0

    for i in range(frame_cnt):
        """------------------------ FDT padding -----------------------------"""
        if i < PADDING_LEN_MARK -1: # 不足len_mark个点 -> 继续等数据（index从0开始）
            continue
        elif i < c_in -1: # 不足c_in个点 -> 尾数填充
            seq_len = i+1
            input_i = np.array(input_seq[0:seq_len])
            input_data_i = np.concatenate((input_i, np.ones((c_in - seq_len)) * input_i[-1])) # 尾数padding
        else:
            input_data_i = np.array(input_seq[i-c_in +1 : i+1])

        """----------------------- FDT 计算结果 ------------------------------"""
        res_upDown, h_0 = demo_0.press_detect(input_data_i, h_0)

        if decision_mode == 0 :
            if res_upDown == 2 :
                count_up = len([x for x in MemSeq if x == 0]) # MemSeq中为0-up的数量
                count_down = len([x for x in MemSeq if x == 1]) # MemSeq中为1-down的数量
                res_trans = 0 if MemSeq[-1] == 0 else 1 if count_down > count_up else 0
                res_upDown = res_trans

        elif decisioin_mode == 1:
            if res_upDown == 0:
                downCount = 0   # pred结果为0时count重置
                upCount += 1
                if MemSeq[-1] == 1 and upCount < upMemCount:
                    res_upDown = 1

                elif res_upDown == 1:
                    upCount = 0   # pred结果为0时count重置
                    downCount += 1
                    if MemSeq[-1] == 1 and downCount < upMemCount:
                        res_upDown = 1

                elif res_upDown == 2:
                    upCount = 0   # pred结果为0时count重置
                    downCount = 0
                    res_upDown = MemSeq[-1]

        # 更新MemSeq FIFO方式
        MemSeq.pop(0)
        MemSeq.append(res_upDown)
        PredRes.append(res_upDown)

    if True:
        show_result(PredRes, input_seq, frame_cnt, c_in, PADDING_LEN_MARK)

    return None
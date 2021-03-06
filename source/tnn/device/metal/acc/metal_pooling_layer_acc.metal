// Tencent is pleased to support the open source community by making TNN available.
//
// Copyright (C) 2020 THL A29 Limited, a Tencent company. All rights reserved.
//
// Licensed under the BSD 3-Clause License (the "License"); you may not use this file except
// in compliance with the License. You may obtain a copy of the License at
//
// https://opensource.org/licenses/BSD-3-Clause
//
// Unless required by applicable law or agreed to in writing, software distributed
// under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the 
// specific language governing permissions and limitations under the License.

#include <metal_stdlib>
#include "tnn/device/metal/acc/metal_common.metal"

using namespace metal;
kernel void pooling_max(const device ftype4 *in            [[buffer(0)]],
                        device ftype4 *out                 [[buffer(1)]],
                        constant MetalPoolParams& params   [[buffer(2)]],
                        uint3 gid                          [[thread_position_in_grid]]) {
    if (any(gid >= uint3(params.output_width, params.output_height, params.output_slice*params.batch)))
        return;
    
    int off_x = gid.x * params.stride_x - params.pad_x;
    int off_y = gid.y * params.stride_y - params.pad_y;
    
    int y_min = clamp(off_y, 0, params.input_height);
    int y_max = clamp(off_y + params.kernel_y, 0, params.input_height);
    int x_min = clamp(off_x, 0, params.input_width);
    int x_max = clamp(off_x + params.kernel_x, 0, params.input_width);
    
    auto z_in = in + (int)gid.z * params.input_size;
    auto result = z_in[y_min * params.input_width + x_min];
    for (int y = y_min; y < y_max; y++) {
        auto y_in = z_in + y * params.input_width;
        for (int x = x_min; x < x_max; x++) {
            result = max(result, y_in[x]);
        }
    }
    out[(int)gid.z * params.output_size + (int)gid.y * params.output_width + (int)gid.x] = result;
}

kernel void pooling_avg(const device ftype4 *in            [[buffer(0)]],
                        device ftype4 *out                 [[buffer(1)]],
                        constant MetalPoolParams& params   [[buffer(2)]],
                        uint3 gid                          [[thread_position_in_grid]]) {
    if (any(gid >= uint3(params.output_width, params.output_height, params.output_slice*params.batch)))
        return;
    
    int off_x = gid.x * params.stride_x - params.pad_x;
    int off_y = gid.y * params.stride_y - params.pad_y;

    int y_min = clamp(off_y, 0, params.input_height);
    int y_max = clamp(off_y + params.kernel_y, 0, params.input_height);
    int x_min = clamp(off_x, 0, params.input_width);
    int x_max = clamp(off_x + params.kernel_x, 0, params.input_width);
    
    auto z_in = in + (int)gid.z * params.input_size;
    float4 result = 0;
    for (int y = y_min; y < y_max; y++) {
        auto y_in = z_in + y * params.input_width;
        for (int x = x_min; x < x_max; x++) {
            result += float4(y_in[x]);
        }
    }
    
    int count = (y_max - y_min) * (x_max - x_min);
    float4 div = count > 0 ? 1.f / count : 0.0;
    out[(int)gid.z * params.output_size + (int)gid.y * params.output_width + (int)gid.x] = ftype4(result * div);
}

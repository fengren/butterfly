use std::os::raw::{c_float, c_int};

/// Simple denoise: set values below threshold to zero
fn simple_denoise(samples: &[f32], threshold: f32) -> Vec<f32> {
    samples
        .iter()
        .map(|&x| if x.abs() < threshold { 0.0 } else { x })
        .collect()
}

/// Generate waveform data with denoise and downsampling
#[unsafe(no_mangle)]
pub extern "C" fn generate_waveform_with_denoise(
    samples: *const c_float,
    length: c_int,
    target_points: c_int,
    denoise_threshold: c_float,
    out_waveform: *mut c_float,
) {
    // Safety: caller must guarantee valid pointers and lengths
    let samples = unsafe { std::slice::from_raw_parts(samples, length as usize) };
    let denoised = simple_denoise(samples, denoise_threshold);
    let chunk_size = if target_points > 0 {
        denoised.len() / target_points as usize
    } else {
        0
    };
    let out_waveform =
        unsafe { std::slice::from_raw_parts_mut(out_waveform, target_points as usize) };
    for i in 0..target_points as usize {
        let start = i * chunk_size;
        let end = ((i + 1) * chunk_size).min(denoised.len());
        let chunk = &denoised[start..end];
        out_waveform[i] = chunk.iter().map(|x| x.abs()).fold(0.0, f32::max);
    }
}

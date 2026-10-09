# Temporal filter choices

Open **Filtering** in Studio, choose low-pass/high-pass/band-pass/band-stop and a filter family. The dialog shows the final frequency response using the actual TR and available frame count. The Standardized Analysis workflow also has a family selector. Butterworth remains the default.

| Family | What changes when you increase selectivity |
| --- | --- |
| Butterworth | Smooth passband; gradually attenuates frequencies beyond the cutoff. |
| Chebyshev I | Steeper transition with passband ripple; cutoff denotes the passband edge. |
| Chebyshev II | Flat passband with stopband ripple; cutoff denotes the **stopband** edge. |
| Elliptic | Sharp transition with passband and stopband ripple. |
| FIR, Hamming window | Increase order for a narrower transition; longer records are required. |
| FFT, strict bins | Zeros excluded discrete Fourier bins of the filtered segment, to numerical precision. |

IIR/FIR filters use forward/backward filtering: zero phase and final magnitude `|H(f)|^2`. Ripple and stopband attenuation settings describe this **final** two-pass response, so the IIR designer uses half the specified dB values. Butterworth's nominal cutoff becomes approximately −6 dB after two passes. IIR band-pass/stop designs have twice the prototype order; metadata records the actual design and effective two-pass orders. Second-order sections avoid the numerical instability of high-order transfer-form IIR filtering. Finite-record edge estimates can differ from the former transfer-form Butterworth implementation.

FFT bins have spacing `Fs/N`, where `Fs=1/TR` and `N` is the number of samples after trimming. The symmetric mask keeps both positive and negative frequencies. It is a periodic, finite-record projection: it does not separate all motion artifacts from physiology and may ring around spikes and discontinuities between the recording's end and start. An ideal continuous-frequency brick-wall response is not achievable by a finite-length causal filter.

**Preserve voxel mean** is on by default to keep the Doppler baseline suitable for PSC. It explicitly retains the DC component even in high-pass/band-pass mode. Turn it off when you want to reject DC too; the engine filters mean-centered fluctuations. It leaves frames outside the trimmed segment unchanged. Voxels with missing/nonfinite samples are retained rather than filled or silently filtered; their count is recorded.

Cutoffs must be below the acquisition's Nyquist frequency. For example, a 20-second TR has Nyquist `0.025 Hz`, so `0.20 Hz` cannot be used. Dialog defaults adapt to TR, and explicit invalid settings now report an error instead of being silently clamped. Records too short for zero-phase filtering also report the required frame count, rather than switching silently to a causal single-pass filter.

For fast motion spikes, review **Motion correction → Despike / Scrubbing** before low-pass filtering. A brief spike contains energy throughout the spectrum, including low frequencies that any low-pass filter preserves. Filtering is therefore not proof that motion contamination was removed. Avoid choosing a cutoff solely for visual smoothness; check whether it attenuates the physiological response of interest.

Studio saves the derived dataset under its **analysed-data Preprocessing** folder. Metadata contains the family, cutoffs, TR, order, ripple/attenuation settings, zero-phase status, mean-preservation choice, frame range, coefficients/SOS or FFT mask, and QC paths. Nondefault filter families also appear in dataset and saved-file names. Raw data are retained.

For scripts:

```matlab
opts = struct('method','ellip','type','low','FcHigh',0.1,'order',4, ...
    'passbandRippleDb',0.5,'stopbandAttenuationDb',60, ...
    'restoreMean',true,'saveQC',true);
[filtered, stats] = filtering(I, TR, analysedFolder, opts);
% Strict finite-record frequency rejection: opts.method = 'fft';
```

See MathWorks documentation for [elliptic filter specifications](https://www.mathworks.com/help/signal/ref/ellip.html) and [zero-phase filtering](https://www.mathworks.com/help/signal/ref/filtfilt.html). Run `runtests({'tests/testTemporalFilterChoices.m','tests/testFilterStudioIntegration.m'})` to verify filtering and Studio integration.

# Repeated hindpaw stimulation

For a **25-minute total** recording: use 180 seconds of pre-stimulation
baseline, then **22 cycles of 40 seconds ON and 20 seconds OFF**. The last ON
interval is 1440–1480 seconds; the recording ends at 1500 seconds. Active
stimulation totals 880 seconds (14 minutes 40 seconds). Use actual trigger
timestamps if acquisition/stimulation did not start together or any cycles
were interrupted.

Motion registration, artifact/QC review and an aligned tissue mask remain
appropriate. Keep an unsmoothed analysis copy. A 60/120-second display smoother
will blur this one-minute stimulus cycle; it should not be used as the input
for testing the 40/20-second response. Avoid removing components solely
because they explain a large fraction of variance: they may carry the evoked
response. The block repetition frequency is 1/60 Hz (~0.0167 Hz), so a filter
that removes this frequency would remove the experimental effect.

Use **the processed data's TR**, not automatically the raw 0.480-second TR.
For example, if preprocessing produces one frame per 25 raw volumes, the
processed interval is 12 seconds: only about 3–4 samples represent an ON
block and 1–2 an OFF block. Median/frame aggregation can also mix ON and OFF
intervals. Review the acquisition/aggregation timestamps before quantitative
event analysis.

For descriptive per-cycle ROI results:

```matlab
% roiSignals: acquired frames x ROIs, unsmoothed signal values
R = fusiElectricalBlockAnalysis(roiSignals, processedTR);
% If input is already PSC, avoid applying PSC conversion a second time:
R = fusiElectricalBlockAnalysis(roiPSC, processedTR, struct('inputIsPSC',true));
writetable(R.events, 'stimulation_events.csv');
```

The helper uses half-open intervals, omits incomplete cycles, records sample
counts, and does not report p-values. It does not assume the 20-second OFF
period has recovered to baseline. For evoked-response inference, use a GLM
with the verified stimulus times, an appropriate measured/validated
hemodynamic response, nuisance regressors and temporal autocorrelation
handling. Automatic maximum/plateau ROI search is exploratory; predefine ROIs
or use independent data for confirmatory testing.

During-stimulation FC can include shared stimulus-locked responses. To study
residual connectivity, model/remove those responses with a suitable GLM and
calculate FC on the residuals, or separately examine the resting baseline.
Neither ON nor OFF samples should be treated as independent animals.

Primary examples: [fUS hindpaw stimulation and response mapping](https://pmc.ncbi.nlm.nih.gov/articles/PMC11105977/),
[fUS HRF-convolved stimulus modeling](https://pmc.ncbi.nlm.nih.gov/articles/PMC7977620/),
and [evoked-component analysis with regional HRFs](https://pubmed.ncbi.nlm.nih.gov/38687661/).

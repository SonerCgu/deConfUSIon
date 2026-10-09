function proc=fusiApplyBaseline(I,TR,par,baseline,nFrames)
% Recompute from absolute power; keep the viewer's existing temporal grid.
assert(~isempty(I)&&(ndims(I)==3||ndims(I)==4),'deConfUSIon:BaselineRaw', ...
    'Absolute Doppler data are required. Open the raw/preprocessed recording in Studio, then open the viewer.');
T=size(I,ndims(I));factor=(nFrames-1)/(T-1);
assert(T>1&&isfinite(factor)&&factor>=1&&abs(factor-round(factor))<1e-9, ...
    'deConfUSIon:BaselineTimeGrid','Raw data and viewer time grids do not match. Reopen this recording from Studio.');
par.interpol=round(factor);
progress=fusiBaselineProgress('open','Applying baseline to current scan');
guard=onCleanup(@()fusiBaselineProgress('close',progress)); %#ok<NASGU>
par.baselineProgressFcn=@(message)fusiBaselineProgress('update',progress,[],message);
fusiBaselineProgress('update',progress,[],'Recomputing current scan PSC...');
proc=computePSC(I,TR,par,baseline);
assert(size(proc.PSC,ndims(proc.PSC))==nFrames,'deConfUSIon:BaselineTimeGrid','Baseline update changed the frame count.');
fusiBaselineProgress('close',progress);
end

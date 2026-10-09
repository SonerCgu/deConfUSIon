function result=fusiElectricalBlockAnalysis(signal,TR,config)
% Descriptive cycle averages for the 25-min hindpaw stimulation protocol.
% signal is [acquired frames x ROI/voxel traces], before display smoothing.
% This does not estimate an HRF or provide significance tests.
if nargin<3,config=struct();end
c=struct('baselineSec',180,'onSec',40,'offSec',20,'totalSec',1500,'startSec',0,'inputIsPSC',false);
keys=fieldnames(config);for k=1:numel(keys),assert(isfield(c,keys{k}),'Unknown setting: %s',keys{k});c.(keys{k})=config.(keys{k});end
validateattributes(signal,{'numeric'},{'2d','nonempty'});validateattributes(TR,{'numeric'},{'scalar','positive','finite'});
for key={'baselineSec','onSec','offSec','totalSec'},validateattributes(c.(key{1}),{'numeric'},{'scalar','positive','finite'});end
validateattributes(c.startSec,{'numeric'},{'scalar','nonnegative','finite'});
assert(c.totalSec>c.baselineSec,'Total recording must extend beyond baseline.');
period=c.onSec+c.offSec;n=floor((c.totalSec-c.baselineSec)/period);
onsets=c.baselineSec+(0:n-1)'*period;offsets=onsets+c.onSec;
timeSec=c.startSec+(0:size(signal,1)-1)'*TR;
baseline=timeSec>=0&timeSec<c.baselineSec;assert(nnz(baseline)>=3,'At least 3 pre-stimulation baseline samples are required.');
x=double(signal);baselineMean=mean(x(baseline,:),1,'omitnan');
if c.inputIsPSC,psc=x;else,den=baselineMean;den(~isfinite(den)|den==0)=NaN;psc=100*(x-den)./den;end
inScan=timeSec<c.totalSec;psc(~inScan,:)=NaN;
onMean=nan(n,size(x,2));offMean=onMean;onSamples=zeros(n,1);offSamples=onSamples;
for k=1:n
 on=timeSec>=onsets(k)&timeSec<offsets(k);off=timeSec>=offsets(k)&timeSec<onsets(k)+period;
 onSamples(k)=nnz(on);offSamples(k)=nnz(off);
 % A truncated cycle is missing, not extrapolated or filled from another scan.
 if timeSec(end)+TR+1e-8<onsets(k)+period,continue;end
 if any(on),onMean(k,:)=mean(psc(on,:),1,'omitnan');end
 if any(off),offMean(k,:)=mean(psc(off,:),1,'omitnan');end
end
result=struct('config',c,'TR',TR,'timeSec',timeSec,'PSC',psc,'baselineMean',baselineMean, ...
 'events',table(onsets,repmat(c.onSec,n,1),'VariableNames',{'onsetSec','durationSec'}), ...
 'cycleOnMeanPSC',onMean,'cycleOffMeanPSC',offMean,'onSamples',onSamples,'offSamples',offSamples, ...
 'nCycles',n,'activeSec',n*c.onSec,'periodSec',period, ...
 'note','Descriptive block averages only. OFF periods can contain delayed vascular responses. Use actual processed TR and acquisition timing; inferential GLM requires a validated HRF and temporal-noise model.');
end

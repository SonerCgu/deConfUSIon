function p=fusiVolumeSequencePlan(q)
% Compact movie timeline; never concatenate or preload the power movies.
included=find(fusiScanSequence('included',q));assert(~isempty(included), ...
 'deConfUSIon:VolumeSequenceEmpty','Include at least one scan in Scans / order.');
p=struct('frames',[],'scanIndices',[],'localFrames',[],'timeSec',[],'localTimeSec',[], ...
 'scanLabels',{{}},'scanKeys',{{}},'sampleTRSec',[]);offset=0;
for k=included
 d=q.scans{k};n=d.nFrames;local=(0:n-1)*d.TR;
 p.scanIndices=[p.scanIndices repmat(k,1,n)];p.localFrames=[p.localFrames 1:n]; %#ok<AGROW>
 p.timeSec=[p.timeSec offset+local];p.localTimeSec=[p.localTimeSec local]; %#ok<AGROW>
 p.sampleTRSec=[p.sampleTRSec repmat(d.TR,1,n)]; %#ok<AGROW>
 p.scanLabels{end+1}=d.label;p.scanKeys{end+1}=d.key;
 offset=offset+n*d.TR;
end
p.frames=1:numel(p.localFrames);p.includedScanIndices=included;p.durationSec=offset;
end

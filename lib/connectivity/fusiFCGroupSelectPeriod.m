function subjects=fusiFCGroupSelectPeriod(subjects,period)
% Never substitute a different epoch when the requested period was not saved.
if strcmpi(period,'Current export'),return;end
for k=1:numel(subjects)
 assert(isfield(subjects(k),'allEpochs'),'deConfUSIon:FCPeriodMissing','This legacy bundle has no saved time periods. Select Current export or re-export the FC results.');
 epochs=subjects(k).allEpochs;hit=[];
 for e=1:numel(epochs)
  if startsWith(lower(epochs(e).epochName),lower(period))&&isfield(epochs(e).roi,'R')&&~isempty(epochs(e).roi.R),hit=e;break;end
 end
 assert(~isempty(hit),'deConfUSIon:FCPeriodMissing','%s has no calculated %s period. Calculate it in FC and export again.',subjects(k).name,period);
 rec=epochs(hit);roi=rec.roi;
 for field={'R','Z','labels','names','meanTS','timeIdx','counts'}
  if isfield(roi,field{1}),subjects(k).(field{1})=roi.(field{1});end
 end
 subjects(k).epochName=rec.epochName;subjects(k).displayMatrix=roi.R;subjects(k).displayZ=roi.Z;
 subjects(k).displayLabels=roi.labels;subjects(k).displayNames=roi.names;
 subjects(k).sliceResults=struct([]);if isfield(rec,'sliceResults'),subjects(k).sliceResults=rec.sliceResults;end
end
end

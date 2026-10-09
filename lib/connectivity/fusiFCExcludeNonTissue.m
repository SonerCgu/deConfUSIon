function subj=fusiFCExcludeNonTissue(subj)
% Apply named CSF exclusions to seed masks as well as region matrices.
if isempty(subj.roiAtlas)||isempty(subj.mask),return;end
T=subj.roiNameTable;excluded=997;
if isstruct(T)&&isfield(T,'labels')&&isfield(T,'names')
 for k=1:min(numel(T.labels),numel(T.names))
  name=char(T.names{k});if isfield(T,'fullNames')&&k<=numel(T.fullNames),name=[name ' ' char(T.fullNames{k})];end
  if ~isempty(regexpi(name,'\<ventricles?\>|\<ventricular (system|space|cavity)|cerebral aqueduct|choroid plexus|\<background\>|\<root\>','once'))
   excluded(end+1)=abs(double(T.labels(k))); %#ok<AGROW>
  end
 end
end
subj.mask(ismember(abs(subj.roiAtlas),excluded))=false;
end

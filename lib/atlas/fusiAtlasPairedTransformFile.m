function file=fusiAtlasPairedTransformFile(meta,underlayFile)
% Resolve an existing exact transform; otherwise retain the embedded affine.
file=underlayFile;candidates={};
if isfield(meta,'selectedTransformFile'),candidates{end+1}=meta.selectedTransformFile;end
candidates{end+1}=fullfile(fileparts(underlayFile),'Transformation.mat');
if isfield(meta,'transformFile'),candidates{end+1}=meta.transformFile;end
for k=1:numel(candidates)
 candidate=char(candidates{k});if isempty(candidate)||~isfile(candidate),continue;end
 try
  S=load(candidate,'Transf');
  if isfield(S,'Transf')&&isfield(S.Transf,'scanGeometry')&& ...
    isequaln(S.Transf.M,meta.transform.M)&&isequaln(S.Transf.scanGeometry,meta.transform.scanGeometry)
   file=candidate;return;
  end
 catch
 end
end
end

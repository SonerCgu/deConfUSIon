function [R,Z]=fusiFCGroupMatrix(subj,sliceMode)
% Align every matrix to signed whole-volume region IDs, even on sparse slices.
labels=double(subj.labels(:));n=numel(labels);R=nan(n);Z=nan(n);
if nargin<2,sliceMode='All slices';end
token=regexp(char(sliceMode),'\d+','match','once');
if isempty(token)
 if isfield(subj,'R'),R=double(subj.R);elseif isfield(subj,'M'),R=double(subj.M);end
 if isfield(subj,'Z'),Z=double(subj.Z);else,Z=atanh(max(-.999999,min(.999999,R)));Z(1:n+1:end)=0;end
else
 z=str2double(token);if ~isfield(subj,'sliceResults'),return;end
 records=subj.sliceResults;hit=[];
 for k=1:numel(records)
  if isfield(records(k),'sliceIndex')&&isequal(double(records(k).sliceIndex),z),hit=k;break;end
 end
 if isempty(hit)&&~isfield(records,'sliceIndex')&&z<=numel(records),hit=z;end
 if isempty(hit),return;end
 r=records(hit);if ~isfield(r,'labels')||isempty(r.labels),return;end
 [present,indices]=ismember(double(r.labels(:)),labels);indices=indices(present);
 if isfield(r,'R'),values=double(r.R);elseif isfield(r,'M'),values=double(r.M);else,return;end
 R(indices,indices)=values(present,present);
 if isfield(r,'Z'),values=double(r.Z);else,values=atanh(max(-.999999,min(.999999,values)));values(1:size(values,1)+1:end)=0;end
 Z(indices,indices)=values(present,present);
end
assert(isequal(size(R),[n n])&&isequal(size(Z),[n n]),'deConfUSIon:FCGroupGrid','FC matrices must match their signed region IDs.');
end

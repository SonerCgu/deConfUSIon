function order=scmCandidateOrder(candidates,role,sliceRange,sortMode)
% Return original candidate indices; view sorting must never change ROI IDs.
if isempty(candidates), order=[]; return; end
z=cellfun(@(c)c.slice,candidates); score=cellfun(@(c)c.meanPSC,candidates);
z=z(:)'; score=score(:)';
keep=z>=min(sliceRange)&z<=max(sliceRange);
for k=1:numel(candidates)
    if isfield(candidates{k},'activeSlices')
        keep(k)=any(candidates{k}.activeSlices>=min(sliceRange)&candidates{k}.activeSlices<=max(sliceRange));
    end
end
if ~strcmp(role,'All'), keep=keep&cellfun(@(c)strcmp(c.role,role),candidates); end
order=find(keep);
switch sortMode
    case 1
        ranked=score;
        for k=order,if isfield(candidates{k},'rankingScore'),ranked(k)=candidates{k}.rankingScore;end,end
        keys=[-ranked(order)' z(order)'];
    case 2, keys=[score(order)' z(order)'];
    case 3, keys=[z(order)' -score(order)'];
    case 4, keys=[-z(order)' -score(order)'];
end
[~,ix]=sortrows(keys,[1 2]); order=order(ix);
end

function selected=scmTopCandidates(candidates,counts)
% Rank independently per atlas region and role, one candidate per slice.
assert(isnumeric(counts)&&numel(counts)==2&&all(isfinite(counts))&& ...
    all(counts>=0&counts==round(counts)), ...
    'deConfUSIon:TopROICount','Top ROI counts must be two nonnegative integers.');
selected={};roles={'Target','Control'};
neutral=all(cellfun(@(c)strcmp(c.role,'Search'),candidates));
if neutral,roles={'Search'};counts=max(counts);end
for ri=1:numel(roles)
    subset=candidates(cellfun(@(c)strcmp(c.role,roles{ri}),candidates));
    if isempty(subset)
        assert(counts(ri)==0,'deConfUSIon:TopROICount','No valid %s candidate is available for the requested top-N selection.',roles{ri});
        continue;
    end
    groups=cellfun(@scmCandidateRegionKey,subset,'UniformOutput',false);
    keys=unique(groups,'stable');
    for gi=1:numel(keys)
        group=subset(strcmp(groups,keys{gi}));
        scores=cellfun(@(c)c.meanPSC,group);slices=cellfun(@(c)c.slice,group);
        assert(numel(unique(slices))==numel(slices),'deConfUSIon:TopROICount','Expected one candidate per region, role and slice.');
        [~,order]=sortrows([-scores(:) slices(:)],[1 2]);
        count=counts(ri);
        assert(count<=numel(group),'deConfUSIon:TopROICount', ...
            'Requested %d %s ROIs per region, but only %d slices have a valid candidate in this region. Reduce the count or expand the search.',count,roles{ri},numel(group));
        if count==0,count=numel(group);end
        for rank=1:count
            c=group{order(rank)};c.selectionRank=rank;c.requestedTopN=counts(ri);
            c.selectedRoleCount=count;
            c.rankingRule='Descending selected-window mean PSC; one best ROI per region, role and slice; ties use ascending slice. Exploratory selection, not outlier removal.';
            selected{end+1}=c; %#ok<AGROW>
        end
    end
end
end

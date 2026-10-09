function key=scmCandidateRegionKey(c)
% Atlas identity remains separate when ranking several selected regions.
key='all';
if isfield(c,'atlasRegion')&&~isempty(c.atlasRegion)
    key=sprintf('atlas:%g',c.atlasRegion.id);
end
end

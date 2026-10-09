function handles=fusiDrawRegionBoundaries(ax,L)
% Visible parent-region contours, calculated only for the displayed plane.
handles=gobjects(0);L(L<=1)=0;[x,y]=fusiRegionBoundarySegments(L);
if ~isempty(x),handles=line(ax,x,y,'Color','w','LineStyle',':','LineWidth',.8,'HitTest','off','Tag','AtlasParentBoundary');end
end

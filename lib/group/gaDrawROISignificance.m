function gaDrawROISignificance(ax,R,S,color)
% One label above a bracket, with a pixel-sized gap and reserved headroom.
delete(findall(ax,'Tag','GA_ROI_PLabel'));delete(findall(ax,'Tag','GA_ROI_PBracket'));
if ~isfield(R,'stats')||~isfield(R.stats,'p')||~isscalar(R.stats.p),return;end
if ~isfinite(R.stats.p),return;end
p=R.stats.p;if p<0||p>1,return;end
if p<.001,stars='***';elseif p<.01,stars='**';elseif p<.05,stars='*';else,stars='n.s.';end
showP=true;if isfield(S,'showPText'),showP=logical(S.showPText);end
label=stars;if showP,label=[stars '   ' gaFormatPValue(p)];end
pos=getpixelposition(ax,true);height=max(90,pos(4));
gap=8/height; tick=6/height; top=12/height; textHeight=20/height;
yl=ylim(ax);span=diff(yl);if ~isfinite(span)||span<=0,return;end
auto=true;if isfield(S,'plotBot')&&isfield(S.plotBot,'auto'),auto=logical(S.plotBot.auto);end
if auto && isfield(R,'metricVals')
    v=R.metricVals(isfinite(R.metricVals));
    if ~isempty(v)
        reserve=min(.65,top+textHeight+gap+tick+12/height);
        % Reserve room over points/means instead of placing the line through them.
        upper=max(yl(2),yl(1)+(max(v)-yl(1))/(1-reserve));
        if upper>yl(2),ylim(ax,[yl(1) upper]);yl=ylim(ax);span=diff(yl);end
    end
end
yNorm=1-top-textHeight-gap;
yBar=yl(1)+yNorm*span;
groups=2;if isfield(R,'groupNames'),groups=numel(R.groupNames);end
pairwise=groups==2;
if isfield(R.stats,'type')
    kind=lower(R.stats.type);
    pairwise=pairwise && ~contains(kind,'anova') && ~contains(kind,'one-sample');
end
x=mean(xlim(ax));
if pairwise
    line(ax,[1 1 2 2],[yBar-tick*span yBar yBar yBar-tick*span], ...
        'Color',color,'LineWidth',1.5,'Tag','GA_ROI_PBracket','HandleVisibility','off');
    x=1.5;
end
xl=xlim(ax);xNorm=(x-xl(1))/diff(xl);
text(ax,xNorm,yNorm+gap,label,'Units','normalized','Color',color, ...
    'FontName','Arial','FontSize',12,'FontWeight','bold','Interpreter','none', ...
    'HorizontalAlignment','center','VerticalAlignment','bottom','Clipping','off', ...
    'Tag','GA_ROI_PLabel','HandleVisibility','off');
end

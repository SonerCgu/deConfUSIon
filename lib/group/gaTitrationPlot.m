function D=gaTitrationPlot(ax,R,S,fg,colA,colB,showLabels)
% aCSF is a single independent category; the remaining categories are doses.
set(ax,'FontName','Arial','FontWeight','bold','LineWidth',1.2);
legend(ax,'off');
% cla leaves HandleVisibility='off' graphics alive. Remove our own marks
% explicitly so changing display preferences cannot retain old error bars.
for tag={'GA_TitrationAnimals','GA_TitrationMean','GA_TitrationError', ...
        'GA_TitrationPair','GA_TitrationAnimalLabel','GA_TitrationBracket', ...
        'GA_TitrationPValue','GA_TitrationEmpty'}
    delete(findall(ax,'Tag',tag{1}));
end
D=gaTitration('summarize',R,S);setappdata(ax,'GA_TitrationResult',D);
for key={'GA_ROI_PairingReport','GA_TitrationBracketLayout'}
    if isappdata(ax,key{1}),rmappdata(ax,key{1});end
end
if isempty(D.categories)
    text(ax,.5,.5,{'Assign concentrations to treatment animal/scan rows using Assign doses...', ...
        'Select the aCSF source Group; control rows need no concentration.'},'Units','normalized', ...
        'HorizontalAlignment','center','Color',fg,'Interpreter','none','Tag','GA_TitrationEmpty');
    xlim(ax,[0 1]);ylim(ax,[0 1]);return;
end
hold(ax,'on');cats=D.categories;nc=numel(cats);P=D.categoryPoints;
logX=strcmpi(D.xScale,'Log concentration');base=(1:nc)';transform=@(x)x;
if logX
    dose=[cats.doseM];finite=sort(unique(dose(isfinite(dose))));gap=1;
    if numel(finite)>1,gap=min(diff(log10(finite)));end
    if ~isempty(finite)
        base=log10(dose(:));
        base(~isfinite(base))=log10(min(finite))-gap;
        for d=finite
            at=find(dose==d);if numel(at)>1,base(at)=base(at)+linspace(-.12,.12,numel(at))'*gap;end
        end
        transform=@(x)10.^x;set(ax,'XScale','log');
    else,logX=false;set(ax,'XScale','linear');end
else,set(ax,'XScale','linear');end
gap=1;if numel(unique(base))>1,gap=min(diff(sort(unique(base))));end
colours=lines(max(2,nc));pointX=nan(1,numel(P));means=gobjects(0);legendNames={};
allY=reshape([P.value],[],1);
for c=1:nc
    if strcmp(cats(c).role,'control'),colours(c,:)=colB;
    elseif contains(lower(cats(c).group),'pacap'),colours(c,:)=colA;end
    at=find(strcmp({P.categoryKey},cats(c).key));jitter=zeros(size(at));
    if numel(at)>1,jitter=linspace(-.07,.07,numel(at))*gap;end
    pointX(at)=transform(base(c)+jitter);
    if ~isfinite(D.categoryMean(c)),continue;end
    % Horizontal means leave the individual animal values visible.
    plot(ax,transform(base(c)+[-.20 .20]*gap),[1 1]*D.categoryMean(c),'-', ...
        'Color',colours(c,:),'LineWidth',3,'HandleVisibility','off','Tag','GA_TitrationMean');
    err=D.categorySEM(c);if strcmpi(D.errorBand,'SD'),err=D.categorySD(c);end
    if ~strcmpi(D.errorBand,'None')&&isfinite(err)
        errorbar(ax,transform(base(c)),D.categoryMean(c),err,'LineStyle','none', ...
            'Color',colours(c,:),'LineWidth',1.2,'CapSize',8,'HandleVisibility','off','Tag','GA_TitrationError');
        allY=[allY;D.categoryMean(c)-err;D.categoryMean(c)+err]; %#ok<AGROW>
    end
end
if setting(S,'previewConnectAnimals',false)
    animals=unique({P.animalKey},'stable');
    for a=1:numel(animals)
        at=find(strcmp({P.animalKey},animals{a}));if numel(at)<2,continue;end
        [~,order]=sort(pointX(at));at=at(order);
        color=setting(S,'previewPairColor',[]);if isempty(color),color=fg*.5;end
        opacity=setting(S,'previewPairOpacity',1);color=opacity*color+(1-opacity)*get(ax,'Color');
        plot(ax,pointX(at),[P(at).value],'-','Color',color,'LineWidth',setting(S,'previewPairLineWidth',1.2), ...
            'HandleVisibility','off','Tag','GA_TitrationPair');
    end
end
for c=1:nc
    at=find(strcmp({P.categoryKey},cats(c).key));if isempty(at),continue;end
    h=scatter(ax,pointX(at),[P(at).value],65,'MarkerFaceColor',colours(c,:), ...
        'MarkerEdgeColor',colours(c,:),'LineWidth',.8,'Tag','GA_TitrationAnimals');
    name=cats(c).group;if strcmp(cats(c).role,'control'),name='aCSF';end
    if ~any(strcmpi(legendNames,name)),means(end+1)=h;legendNames{end+1}=name;else,set(h,'HandleVisibility','off');end %#ok<AGROW>
    if showLabels
        for i=at,text(ax,pointX(i),P(i).value,[' ' P(i).animalID],'Color',fg,'FontSize',9, ...
                'Interpreter','none','VerticalAlignment','bottom','Tag','GA_TitrationAnimalLabel');end
    end
end
centres=transform(base);
set(ax,'XTick',centres,'XTickLabel',{cats.label},'XTickLabelRotation',0);
xlim(ax,transform([min(base)-.5*gap max(base)+.5*gap]));
if logX,xlabel(ax,'Concentration (log spacing; aCSF offset)','Color',fg);
else,xlabel(ax,'Concentration','Color',fg);end
ylabel(ax,setting(R,'metricName','Response'),'Interpreter','none','Color',fg);
if isfield(R,'unitsPercent')&&R.unitsPercent,ylabel(ax,'PSC (%)','Color',fg);end
set([get(ax,'XLabel') get(ax,'YLabel')],'FontName','Arial','FontSize',12,'FontWeight','bold');
cfg=setting(S,'plotBot',struct('auto',true));allY=allY(isfinite(allY));
if ~setting(cfg,'auto',true)&&setting(cfg,'ymax',1)>setting(cfg,'ymin',0)
    lo=setting(cfg,'ymin',0);if setting(cfg,'forceZero',false),lo=0;end;ylim(ax,[lo cfg.ymax]);
elseif ~isempty(allY)
    lo=min(allY);hi=max(allY);span=max(hi-lo,max(abs(allY))*.1);if span==0,span=1;end
    if setting(cfg,'forceZero',false),lo=0;hi=max(0,hi);else,lo=lo-.12*span;end
    ylim(ax,[lo hi+.18*span]);
end
step=setting(cfg,'step',0);
if isfinite(step)&&step>0
    yl=ylim(ax);first=ceil(yl(1)/step)*step;last=floor(yl(2)/step)*step;
    if (last-first)/step<1000,set(ax,'YTick',first:step:last);end
end
if ~isempty(means)&&setting(S,'titrationShowLegend',true)
    legend(ax,means,legendNames,'Location','northeast','TextColor',fg,'Color','none', ...
        'Box','off','FontWeight','bold','Interpreter','none','AutoUpdate','off','Tag','GA_TitrationLegend');
end
title(ax,'');
top=0;if ~isempty(allY),top=max(allY);else,limits=ylim(ax);top=mean(limits);end
gaTitrationBrackets('draw',ax,D,S,centres,top,fg);hold(ax,'off');
end

function out=setting(S,name,fallback)
out=fallback;if isfield(S,name)&&~isempty(S.(name)),out=S.(name);end
end

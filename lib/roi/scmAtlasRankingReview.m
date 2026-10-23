function review=scmAtlasRankingReview(reports,skipped,ctx)
% Ranked atlas table and exact whole-region time-course preview.
review=figure('Name',['Atlas region ranking | ' ctx.sourceLabel],'Tag','SCMAtlasRankingReview', ...
    'NumberTitle','off','MenuBar','none','ToolBar','none','Color',[.07 .09 .12], ...
    'Position',[100 80 1250 800]);movegui(review,'center');
setappdata(review,'deConfUSIonNoMaximize',true);setappdata(review,'SCMOwner',ctx.owner);
setappdata(review,'AtlasRankingReports',reports);setappdata(review,'AtlasRankingSkipped',skipped);
names=cellfun(@(r)r.sourceScanLabel,reports,'UniformOutput',false);
pScan=uicontrol(review,'Style','popupmenu','Units','normalized','Position',[.025 .925 .62 .045], ...
    'String',names,'FontSize',12,'Callback',@refresh,'Tag','AtlasRankingReviewScan');
uicontrol(review,'Style','pushbutton','Units','normalized','Position',[.72 .925 .255 .05], ...
    'String','Export tables + curves','FontSize',12,'FontWeight','bold', ...
    'BackgroundColor',[.08 .42 .31],'ForegroundColor','w','Callback',@export,'Tag','AtlasRankingExport');
description=uicontrol(review,'Style','text','Units','normalized','Position',[.025 .83 .95 .08], ...
    'BackgroundColor',review.Color,'ForegroundColor','w','HorizontalAlignment','left','FontSize',11);
grid=uitable(review,'Units','normalized','Position',[.025 .415 .95 .41],'Tag','AtlasRankingTable', ...
    'ColumnEditable',false,'RowName',[],'FontSize',11,'CellSelectionCallback',@select);
ax=axes('Parent',review,'Units','normalized','Position',[.075 .10 .88 .25], ...
    'Color',[.03 .04 .06],'XColor','w','YColor','w','Tag','AtlasRankingCurve');
status=uicontrol(review,'Style','text','Units','normalized','Position',[.025 .02 .95 .055], ...
    'BackgroundColor',review.Color,'ForegroundColor',[.65 .85 .9],'HorizontalAlignment','left','FontSize',11);
if ~isempty(skipped),status.String=strjoin(skipped,' | ');end
setappdata(review,'AtlasRankingExport',@(folder)scmExportAtlasRanking(reports,skipped,folder));
refresh();
    function refresh(varargin)
        r=reports{pScan.Value};grid.Data=table2cell(r.table);
        grid.ColumnName={'Rank','Abbreviation','Region','Atlas ID','Change (%)','Mean (%)','Peak (%)', ...
            'Peak time (min)','Usable voxels','Atlas voxels','Coverage (%)','First slice','Last slice','Slices (n)'};
        grid.ColumnWidth={45 100 250 65 100 100 100 100 95 95 90 75 75 85};
        o=r.settings;
        description.String=sprintf(['%s / %s | %.4g-%.4g min | slices %d-%d | %d of %d eligible regions shown\n' ...
            'Whole-region means, both hemispheres combined. Coverage: labelled voxels in selected acquired slices.\n' ...
            'Click a row for its regional curve. %d regions omitted (coverage / outside chosen slices). Ranking is exploratory.'], ...
            o.metric,o.direction,o.signalSec/60,o.sliceRange,height(r.table),r.eligibleRegionCount,height(r.omitted));
        if height(r.table)>0,drawCurve(1);else,cla(ax);title(ax,'No regions meet the selected coverage','Color','w');end
    end
    function select(~,event)
        if isempty(event.Indices),return;end
        drawCurve(event.Indices(1,1));
    end
    function drawCurve(row)
        r=reports{pScan.Value};cla(ax);hold(ax,'on');
        plot(ax,r.timeSec/60,r.traces(row,:),'LineWidth',1.8,'Color',[.12 .75 1]);
        limits=ylim(ax);w=r.settings.signalSec/60;
        patch(ax,w([1 2 2 1]),limits([1 1 2 2]),[.3 .7 .45],'FaceAlpha',.15,'EdgeColor','none');
        plot(ax,xlim(ax),[0 0],':','Color',[.6 .6 .6]);hold(ax,'off');
        xlabel(ax,'Time within scan (min)');ylabel(ax,'Regional mean PSC (%)');
        title(ax,sprintf('%s | %s | mean %.4g%% | %d voxels | %.1f%% coverage', ...
            r.table.Abbreviation{row},r.table.Region{row},r.table.MeanPSC_pct(row), ...
            r.table.UsableVoxels(row),r.table.Coverage_pct(row)),'Interpreter','none','Color','w');
    end
    function export(~,~)
        start=ctx.outputFolder;
        while ~isfolder(start)
            parent=fileparts(start);
            if isempty(parent)||strcmp(parent,start),start=pwd;break;end
            start=parent;
        end
        folder=uigetdir(start,'Choose parent folder for atlas ranking export');if isequal(folder,0),return;end
        folder=fullfile(folder,['AtlasRanking_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);
        try
            scmExportAtlasRanking(reports,skipped,folder);status.String=['Saved tables, curves and audit: ' folder];
        catch ME
            status.String=['Export failed: ' ME.message];
        end
    end
end

function files=fusiFCExportPaperFigure(result,folder)
% Export the displayed selected FC matrix + signed network, with source data.
if ~isfolder(folder),mkdir(folder);end
f=figure('Visible','off','Color','w','Position',[40 40 1500 760]);guard=onCleanup(@()delete(f)); %#ok<NASGU>
R=result.R;names=cellstr(string(result.names));columns=names;
if isfield(result,'columnNames')&&~isempty(result.columnNames),columns=result.columnNames;end
label=@(x)regexprep(regexprep(x,'\s*\[[^\]]*\]\s*$',''),'\s*\|.*$','');
short=label(names);shortColumns=label(columns);
ax=axes(f,'Position',[.08 .20 .38 .68]);imagesc(ax,R,[-result.colourLimit result.colourLimit]);
colormap(ax,result.cmap);colorbar(ax);ax.YDir='reverse';ax.TickLabelInterpreter='none';ax.FontSize=11;
ax.XTick=1:numel(columns);ax.YTick=1:numel(names);ax.XTickLabel=shortColumns;ax.YTickLabel=short;ax.XTickLabelRotation=55;
title(ax,'Region correlations (Pearson r)');
ax2=axes(f,'Position',[.56 .16 .39 .70]);rect={};if ~isequal(names(:),columns(:)),rect=shortColumns;end
[~,h]=fusiFCNetworkPlot(ax2,R,short,result.threshold,result.colourLimit,result.cmap,rect);h.NodeLabelColor=[.1 .1 .1];
set(findall(ax2,'Tag','FCNetworkNodeLabel'),'Color',[.1 .1 .1]);
title(ax2,sprintf('Region network: |r| >= %.2g',result.threshold),'Color','k');colorbar(ax2);
annotation(f,'textbox',[.08 .02 .86 .11],'String',result.caption,'EdgeColor','none','FontSize',11,'Interpreter','none');
stem=fullfile(folder,'FC_selected_regions');
files={[stem '.png'],[stem '.pdf'],[stem '.svg'],[stem '.mat'],[stem '.csv'],fullfile(folder,'FC_region_key.csv')};
exportgraphics(f,files{1},'Resolution',300);exportgraphics(f,files{2},'ContentType','vector','BackgroundColor','white');
print(f,files{3},'-dsvg');save(files{4},'result','-v7.3');
writecell([{'Region'} columns(:)';names(:) num2cell(R)],files{5});
full=names;if isfield(result,'fullNames'),full=result.fullNames;end
keyNames=short(:);keyFull=full(:);matrixLabels=names(:);
if isfield(result,'columnFullNames')
    keyNames=[keyNames;shortColumns(:)];keyFull=[keyFull;result.columnFullNames(:)];matrixLabels=[matrixLabels;columns(:)];
    [keyNames,keep]=unique(keyNames,'stable');keyFull=keyFull(keep);matrixLabels=matrixLabels(keep);
end
writetable(table(keyNames,keyFull,matrixLabels,'VariableNames',{'Abbreviation','FullName','MatrixLabel'}),files{6});
end

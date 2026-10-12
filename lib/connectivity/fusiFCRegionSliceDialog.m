function [chosen,ok]=fusiFCRegionSliceDialog(subj,initial,sliceRange,minVox)
% Search anatomical regions and add explicit region/slice pairs for 3D FC.
chosen=initial;ok=false;bg=[.08 .10 .13];fg=[.96 .96 .96];
if nargin<4,minVox=1;end
valid=logical(subj.mask)&isfinite(subj.roiAtlas)&subj.roiAtlas~=0;
[labels,~,group]=unique(double(subj.roiAtlas(valid)));counts=accumarray(group,1,[numel(labels) 1]);
T=subj.roiNameTable;names=cell(numel(labels),1);
for k=1:numel(labels)
 hit=find(double(T.labels)==labels(k),1);names{k}=sprintf('ROI_%g',labels(k));
 if ~isempty(hit),names{k}=char(T.names{hit});end
end
catalog=fusiFCRegionCatalog(names,T);visible=(1:numel(labels))';
f=figure('Name','Compare regions on different slices','NumberTitle','off','MenuBar','none','ToolBar','none', ...
 'Color',bg,'Position',[130 100 1000 670],'WindowStyle','modal','Tag','FCRegionSliceDialog','CloseRequestFcn',@cancel);
setappdata(f,'deConfUSIonNoMaximize',true);
label('Search abbreviation or full name',[18 620 620 24]);
search=uicontrol(f,'Style','edit','Position',[18 580 630 34],'FontSize',12,'Tag','FCRegionSliceSearch');
regions=uicontrol(f,'Style','listbox','Position',[18 287 630 281],'FontSize',11,'Min',0,'Max',2,'Tag','FCRegionSliceList');
label(sprintf('Slices within Calculate slices: %d-%d',sliceRange),[670 587 310 25]);
sliceEdit=uicontrol(f,'Style','edit','String',num2str(sliceRange(1)),'Position',[670 545 310 34],'FontSize',12,'Tag','FCRegionSliceZ');
label('Examples: 7 or 7 8 20 or 7:10',[670 510 310 26]);
button('Add regions at these slices',[670 455 310 40],[.10 .50 .30],@add);
button('Remove selected entries',[670 394 310 40],[.55 .17 .19],@remove);
label('Each added row is a separate ROI trace. Select at least two rows in total.',[18 251 960 29]);
table=uitable(f,'Position',[18 76 960 173],'ColumnName',{'Region abbreviation','Full name','Slice','Included voxels'}, ...
 'ColumnWidth',{190 500 75 135},'RowName',[],'FontSize',11,'Tag','FCRegionSliceEntries','CellSelectionCallback',@selectRows);
label('The hemisphere menu can keep L/R separate or merge matching sides on the same slice.',[18 38 680 27]);
button('Cancel',[700 18 120 39],[.55 .17 .19],@cancel);
button('Use regions / slices',[831 18 147 39],[.10 .50 .30],@accept);
selectedRows=[];fusiLiveSearch(search,@filter);filter('');render();setappdata(f,'FUSIFCRegionSliceReady',true);uiwait(f);
if isgraphics(f),delete(f);end
 function label(str,pos)
  uicontrol(f,'Style','text','String',str,'Position',pos,'BackgroundColor',bg,'ForegroundColor',fg,'FontSize',11,'HorizontalAlignment','left');
 end
 function button(str,pos,col,cb)
  uicontrol(f,'Style','pushbutton','String',str,'Position',pos,'BackgroundColor',col,'ForegroundColor',fg,'FontSize',11,'FontWeight','bold','Callback',cb);
 end
 function filter(query)
  match=fusiRegionSearchMatch({catalog.acronym},{catalog.name},query);match=match(:)&counts>0;
  visible=find(match);items={catalog(visible).displayName};if isempty(items),items={'No matching regions'};end
  set(regions,'String',items,'Value',1);
 end
 function add(~,~)
  if isempty(visible),return;end
  try
   zs=fusiMovieExportSlices(sliceEdit.String,size(subj.I4,3));
   assert(~isempty(zs)&&all(zs>=sliceRange(1)&zs<=sliceRange(2)),'Choose slices inside Calculate slices.');
   candidate=chosen;
   for index=visible(regions.Value)'
    for z=zs(:)'
     if ~isempty(candidate)&&any([candidate.label]==labels(index)&[candidate.slice]==z),continue;end
     n=nnz(subj.roiAtlas(:,:,z)==labels(index)&subj.mask(:,:,z));
     assert(n>=minVox,'%s has %d included voxels on slice %d; at least %d are required.',catalog(index).acronym,n,z,minVox);
     candidate(end+1)=struct('label',labels(index),'slice',z); %#ok<AGROW>
    end
   end
   chosen=candidate;render();
  catch ME,errordlg(ME.message,'Region / slice selection','modal');end
 end
 function render()
  data=cell(numel(chosen),4);
  for j=1:numel(chosen)
   index=find(labels==chosen(j).label,1);z=chosen(j).slice;
   if isempty(index),data(j,:)={sprintf('ROI_%g',chosen(j).label),'Unavailable region',z,0};continue;end
   data(j,:)={catalog(index).acronym,catalog(index).name,z,nnz(subj.roiAtlas(:,:,z)==labels(index)&subj.mask(:,:,z))};
  end
  table.Data=data;selectedRows=[];
 end
 function selectRows(~,event),selectedRows=unique(event.Indices(:,1));end
 function remove(~,~),chosen(selectedRows)=[];render();end
 function accept(~,~)
  if numel(chosen)<2,errordlg('Add at least two region/slice entries.','Region / slice selection','modal');return;end
  try,fusiFCRegionSliceResult(subj,chosen,1:min(3,size(subj.I4,4)),minVox);
  catch ME,errordlg(ME.message,'Region / slice selection','modal');return;end
  ok=true;uiresume(f);
 end
 function cancel(~,~),ok=false;uiresume(f);end
end

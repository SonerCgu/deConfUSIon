function fusiVolumeControlsLayout(fig,left,root,old,C,atlasOnly)
% Compact persistent controls. Each tab contains one task, not a long list.
old.Visible='off';hidden=uipanel(fig,'Visible','off','Position',[1 1 1 1]);old.Parent=hidden;
tabs=uitabgroup(left,'Tag','VolumeDisplayTabs');tabs.Layout.Row=1;
right=uipanel(root,'Title','Atlas / view','FontSize',17,'ForegroundColor','w','BackgroundColor','k');right.Layout.Column=3;
rg=uigridlayout(right,[1 1],'Padding',[8 8 8 8],'BackgroundColor','k');rt=uitabgroup(rg,'Tag','VolumeAtlasTabs');
if atlasOnly
    make(tabs,'Atlas display',{'backend',''});
else
make(tabs,'Scans',{'scanButton','';'scanChoice','Signal scan';'baselineButton','';'baselineReset',''; ...
 'normalise','';'sequenceMovie','';'baselineNote',''});
make(tabs,'Time',{'backend','';'mode','PSC selection';'fr','Original frame'; ...
    'start','Start (min)';'finish','End (min)';'sliceEdit','Source slices';'excluded','Exclude slices';'maskBox','';'follow',''});
make(tabs,'PSC',{'pscBox','';'signs','Values';'color','Color scheme';'rangeEdit','Range (%)'; ...
    'alpha','Opacity (%)';'strength','3D opacity gain';'clearPSC','';'voxelPSC','';'modulate',''; ...
    'low','Ramp starts (%)';'high','Ramp full (%)';'smooth','Smoothing (px)';'pscCut','Hide below |%|';'pscOnly',''});
make(tabs,'Doppler',{'vessels','';'reference','Reference';'underPreset','Contrast preset'; ...
    'vesselGamma','Display gamma';'vesselGain','Contrast gain';'opacity','Voxel opacity (%)'; ...
    'cutoff','Faint cutoff (%)';'autoBg',''});
end
make(rt,'Atlas',{'loadAtlas','';'clearAtlas','';'adjustAtlas','';'reviewAtlas',''; ...
    'atlasType','Reference';'atlasAlpha','Context opacity (%)';'atlasNote',''});
make(rt,'View',{'viewChoice','Align camera';'motionPath','Movie motion';'motionSpeed','Speed (deg/s)'; ...
 'motionAmplitude','Swing / tilt (deg)';'rotationDuration','Rotation length (s)';'nativeLR','Column 1 side';'nativeConfirmed',''; ...
    'displayLR','Display convention';'lrMarker','L/R marker';'markerX','Marker X (%)';'markerY','Marker Y (%)'; ...
    'rulerBox','';'rulerUnit','Ruler unit';'rulerLength','Ruler length';'rulerPosition','Ruler position';'axesBox','';'movieResolution','Movie resolution';'help',''});
make(rt,'Stack',{'stackView','Camera preset';'stackYaw','Turn (deg)';'stackTilt','Tilt (deg)';'stackRoll','Roll (deg)';'stackGap','Tile gap (%)';'stackStagger','Diagonal rise (%)';'stackTiles','Number of slices';'stackCols','Slices per strip'; ...
    'stackAutoLayout','';'stackAutoFit','';'stackFit',''; ...
    'slabMode','Combine by';'slabCount','Slices per slab';'slabWidth','Slab width (um)';'slabDepthGain','Depth display gain';'stackRange','Slab centers';'stackTimes','Time rows (min)';'stackLabels','';'stackNote',''});
make(rt,'Grid',{'unit','Units';'dy','Row / DV';'dx','Column / LR';'dz','Slice / AP'});
    function make(group,name,items)
        tab=uitab(group,'Title',name,'BackgroundColor','k');
        heights=repmat({34},1,size(items,1));
        if strcmp(name,'Atlas'),heights{end}=125;end
        if strcmp(name,'Stack'),heights{end}=135;end
        if strcmp(name,'Scans'),heights{end}=210;end
        grid=uigridlayout(tab,[size(items,1) 2],'ColumnWidth',{'1x','1x'}, ...
            'RowHeight',heights,'Padding',[8 10 8 10],'RowSpacing',6,'Scrollable','on','BackgroundColor','k');
        for row=1:size(items,1)
            h=C.(items{row,1});h.Parent=grid;h.Visible='on';h.Layout.Row=row;
            if isempty(items{row,2}),h.Layout.Column=[1 2];
            else
                h.Layout.Column=2;label=uilabel(grid,'Text',items{row,2},'WordWrap','on','FontColor','w','FontSize',14);
                label.Layout.Row=row;label.Layout.Column=1;
            end
        end
        % Reparented controls retain old row indices briefly. Reset the
        % grid after moving them, removing automatically appended rows.
        grid.RowHeight=[heights {'1x'}];grid.ColumnWidth={'1x','1x'};
        % Keep the flexible final track in the rendered web layout too.
        spacer=uilabel(grid,'Text','','Visible','on');
        spacer.Layout.Row=numel(heights)+1;spacer.Layout.Column=[1 2];
    end
end

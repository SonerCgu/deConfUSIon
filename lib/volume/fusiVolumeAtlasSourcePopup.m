function popup=fusiVolumeAtlasSourcePopup(owner,onSelect)
% A modeless chooser: no UIWAIT or application-wide modal overlay.
p=owner.Position;position=[p(1)+max(10,(p(3)-450)/2) p(2)+max(20,(p(4)-220)/2) 450 220];
popup=uifigure('Name','Load atlas','Position',position,'WindowStyle','normal','Resize','off', ...
    'Tag','VolumeAtlasSourcePopup','Visible','off','CreateFcn',@(h,~)setappdata(h,'deConfUSIonNoMaximize',true));
setappdata(popup,'deConfUSIonNoMaximize',true);setappdata(popup,'VolumeOwner',owner);
grid=uigridlayout(popup,[4 1],'RowHeight',{52 38 38 32},'Padding',[18 12 18 12]);
uilabel(grid,'Text','Choose a saved transform file or an existing LightSuite project.','WordWrap','on');
uibutton(grid,'Text','Transform file...','Tag','VolumeAtlasChooseFile','ButtonPushedFcn',@(~,~)choose('Transform file'));
uibutton(grid,'Text','LightSuite folder...','Tag','VolumeAtlasChooseLightSuite','ButtonPushedFcn',@(~,~)choose('LightSuite folder'));
uibutton(grid,'Text','Cancel','ButtonPushedFcn',@(~,~)delete(popup));popup.Visible='on';
    function choose(kind)
        delete(popup);
        if isvalid(owner),onSelect(kind);end
    end
end

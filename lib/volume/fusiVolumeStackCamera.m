function camera=fusiVolumeStackCamera(bounds,viewport,angles,points)
% Fit displayed slabs at a selectable oblique angle; never modify data.
center=mean(bounds,2)';extent=diff(bounds,1,2)';
corners=([0 0 0;1 0 0;0 1 0;0 0 1;1 1 0;1 0 1;0 1 1;1 1 1]-.5).*extent;
if nargin>=4 && ~isempty(points)
    center=(min(points,[],1)+max(points,[],1))/2;corners=points-center;
end
yaw=angles(1);tilt=angles(2);roll=angles(3);
direction=[sind(yaw)*cosd(tilt) -sind(tilt) -cosd(yaw)*cosd(tilt)];
forward=-direction;right=cross(forward,[0 -1 0]);right=right/norm(right);up=cross(right,forward);
up=up*cosd(roll)+cross(forward,up)*sind(roll);
right=cross(forward,up);aspect=max(.1,viewport(1)/max(1,viewport(2)));
halfWidth=max(abs(corners*right'));halfHeight=max(abs(corners*up'));
% Stack axes use orthographic projection. Adding a perspective near/far
% allowance needlessly shrinks every slice, particularly a diagonal strip.
distance=1.15*max(halfWidth/aspect,halfHeight)/tand(17.5);
distance=max(distance,1.1*max(abs(corners*forward')));
camera=struct('position',center+direction*max(distance,eps),'target',center,'up',up,'angle',35);
end

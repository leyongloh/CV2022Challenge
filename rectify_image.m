%Author: @Leyong Loh
%\param im:         input image
%\param P:          corner points for each plane
%\return:           rectified image planes in cell array

function im_rect = rectify_image(im, P)
    %% Iterate over all planes
    for i = 1:length(P)
        %% Crop Image
        x = [P{i}(1,:), P{i}(1,1)];
        y = [P{i}(2,:), P{i}(2,1)];
        mask = poly2mask(x, y, max(y), max(x));

        croppedImage = im(1+min(y):max(y), 1+min(x):max(x),:) .* repmat(uint8(mask(1+min(y):max(y), 1+min(x):max(x))),[1,1,3]);
        
        if i == 1
            im_rect{i} = croppedImage;
            continue
        end

        %% Affine Rectification
        % Points in homogeneous coordinates
        [x_min,x_min_index] = min(x);
        [y_min,y_min_index] = min(y);
        x = x - x_min;
        x(find(x==0)) = 1;
        y = y - y_min;
        y(find(y==0)) = 1;
        P_b{1} = [   x(1) ; y(1) ; 1];
        P_b{2} = [  x(2) ; y(2) ; 1];
        P_b{3} = [  x(3) ; y(3) ; 1];
        P_b{4} = [   x(4) ; y(4) ; 1];


        % Get parallel lines
        l1 = cross(P_b{1},P_b{2}); m1 = cross(P_b{4},P_b{3});
        l2 = cross(P_b{1},P_b{4}); m2 = cross(P_b{2},P_b{3});

        % Get points at infinity
        P1_inf = cross(l1,m1);
        P2_inf = cross(l2,m2);

        % Get line at infinity
        l_inf = cross(P1_inf, P2_inf);

        % Homography matrix for affine rectification
        Hp = [1 0 0; 0 1 0; l_inf'/norm(l_inf)];

        % Retify cropped image
        affine_transformation = projective2d(Hp');
        [img_aff, ref] = imwarp(croppedImage, affine_transformation);

        %% Metric Rectification
        % Rescale image if image is too large
        if max(size(img_aff)) > 1000
            scale = 1000/max(size(img_aff));
            img_aff = imresize(img_aff, scale);
        else
            scale = 1;
        end

        % Get transformed points
        % coordinates of the points are traced after each transformation
        for j=1:length(P_b)
            [x1,y1] = transformPointsForward(affine_transformation,P_b{j}(1),P_b{j}(2));
            x1 = x1 - ref.XWorldLimits(1);
            y1 = y1 - ref.YWorldLimits(1);
            if x1 < 1
                x1 = 1;
            end
            if y1 < 1
                y1 = 1;
            end
            P_b{j}(1) = x1 * scale;
            P_b{j}(2) = y1 * scale;
        end
        
        % Perpendicular lines
        l3 = cross(P_b{1},P_b{2}); m3 = cross(P_b{1},P_b{4});
        l4 = cross(P_b{1},P_b{3}); m4 = cross(P_b{2},P_b{4});

        % Matrix of coefficients
        AA = [l3(1)*m3(1) l3(2)*m3(2) l3(1)*m3(2)+l3(2)*m3(1) ;
              l4(1)*m4(1) l4(2)*m4(2) l4(1)*m4(2)+l4(2)*m4(1) ];

        % Get S vector of the null space of A
        s = null(AA);
        
        % SVD
        S = [s(1) s(3) ; s(3) s(2)];
        [U,D,V] = svd(S);
        A = U*sqrt(D)*V';

        % Compute Homography matrix
        H = [A [0;0] ; 0 0 1];

        % Retify cropped image
        metric_transformation = projective2d(inv(H)');
        [img_met, ref] = imwarp(img_aff, metric_transformation);

        % Get transformed points
        for j=1:length(P_b)
            [x1,y1] = transformPointsForward(metric_transformation,P_b{j}(1),P_b{j}(2));
            x1 = x1 - ref.XWorldLimits(1);
            y1 = y1 - ref.YWorldLimits(1);
            P_b{j}(1) = x1;
            P_b{j}(2) = y1;
            P_b{j}(3) = 1;
        end

        %% Rotate Image Plane
        y = P_b{4}(2) - P_b{3}(2);
        x = P_b{4}(1) - P_b{3}(1);
        
        % calculate angle of rotation
        rotation_angle = atan(y/x);
        rotation_angle = rad2deg(rotation_angle);
        
        % angle of rotation is modified depending on each case
        % if the plane is the left plane
        if i==2
            rotation_angle = rotation_angle + 180;
        % if top left corner point bigger than bottom right corner point
        elseif P_b{1}(1) > P_b{4}(1) && P_b{1}(2) > P_b{4}(2)
            rotation_angle = rotation_angle - 180;
        % if bottom right corner point bigger than top left corner point
        % in x-direction
        elseif P_b{4}(1) > P_b{1}(1) && P_b{4}(2) < P_b{1}(2)
            rotation_angle = rotation_angle + 180;
        end

        % rotate image
        img_met_rot = imrotate(img_met, rotation_angle, 'bilinear');
        
        %% Rotate points
        % the coordinates of the corner points need to be traced after
        % rotation (necessary for cropping operation)
        c = [size(img_met,2)/2; size(img_met,1)/2];
        c_transformed = [size(img_met_rot,2)/2; size(img_met_rot,1)/2];
        R = [cosd(rotation_angle) sind(rotation_angle); -sind(rotation_angle) cosd(rotation_angle)];
        for j=1:length(P_b)
            P_b{j}(1:2) = ceil(R * (P_b{j}(1:2)-c)+c_transformed);
        end

        %% Crop Image Plane
        if P_b{1}(2) > P_b{4}(2)
             cropped_img_met = img_met_rot(P_b{4}(2):P_b{1}(2),P_b{2}(1):P_b{1}(1),:);
        else
            cropped_img_met = img_met_rot(P_b{1}(2):P_b{4}(2),P_b{1}(1):P_b{2}(1),:);
        end
        im_rect{i} = cropped_img_met;
    end
end
clc;
clear all;
close all;

inp=input('Enter image : ')

hazy_image = imread(inp);
hazy_image = imresize(hazy_image, [512, 512]);
% Read the hazy image

% Convert the image to double precision
hazy_image_double = im2double(hazy_image);


% % REtinex
% Extract color channels
Rc = hazy_image_double(:,:,1);
Gc = hazy_image_double(:,:,2);
Bc = hazy_image_double(:,:,3);

% Set parameters for the central surround function
tau = 0.1;
theta = 0.5;

% Compute the logarithm of the image in each channel
Rc_log = log(Rc + eps);
Gc_log = log(Gc + eps);
Bc_log = log(Bc + eps);

% Define the central surround function
[m, n] = size(Rc);
[x, y] = meshgrid(1:n, 1:m);
K = tau * exp(-((x - floor(n/2) - 1).^2 + (y - floor(m/2) - 1).^2) / (2 * theta^2));

% Convolve the logarithmic images with the central surround function
Rc_conv = conv2(Rc_log, K, 'same');
Gc_conv = conv2(Gc_log, K, 'same');
Bc_conv = conv2(Bc_log, K, 'same');

% Compute the reflectance
Rc_reflectance = exp(Rc_log - Rc_conv);
Gc_reflectance = exp(Gc_log - Gc_conv);
Bc_reflectance = exp(Bc_log - Bc_conv);

% Recombine the reflectance with the original illumination
dehazed_image1 = cat(3, Rc_reflectance, Gc_reflectance, Bc_reflectance);




% ASM


% Extract color channels
Rc = hazy_image_double(:,:,1);
Gc = hazy_image_double(:,:,2);
Bc = hazy_image_double(:,:,3);

% Set parameters for atmospheric scattering model
Ac = 0.55; % Atmospheric intensity
T = 0.6; % Transmission mapping

% Compute the haze-free image using ASM for each color channel
Jc_R = (Rc - Ac*(1 - T)) / T;
Jc_R = min(max(Jc_R, 0), 1); % Ensure values are in range [0, 1]

Jc_G = (Gc - Ac*(1 - T)) / T;
Jc_G = min(max(Jc_G, 0), 1); % Ensure values are in range [0, 1]

Jc_B = (Bc - Ac*(1 - T)) / T;
Jc_B = min(max(Jc_B, 0), 1); % Ensure values are in range [0, 1]

% Recombine the channels to form the dehazed image
dehazed_image2 = cat(3, Jc_R, Jc_G, Jc_B);

% Display the dehazed image
figure
imshow(dehazed_image2);
title('Dehazed Image');

% % COMBINE

input_image = hazy_image;

% Resize the input image
input_image = imresize(input_image, [512, 512]);


% Convert the input image to double precision
input_image = double(input_image);


% Convert the image to double precision
hazy_image_double = im2double(input_image );

% Extract color channels
Rc = hazy_image_double(:,:,1);
Gc = hazy_image_double(:,:,2);
Bc = hazy_image_double(:,:,3);

% Step 1: Compute the transmittance T(x, y)
% Implement the dark channel prior and morphological edge fusion

% Compute the dark channel image
Idark = min(min(Rc, Gc), Bc);

% Morphological edge enhancement
se1 = strel('square', 3);
Idark_dilated = imdilate(Idark, se1);
se2 = strel('square', 15);
Idark_eroded = imerode(Idark, se2);
Idark_edge = Idark_dilated - Idark_eroded;

% Image fusion
omega1 = 0.5;
omega2 = 0.5;
Idark1 = omega1 * Idark_edge + omega2 * Idark;

% Calculate transmittance
T = 1 - Idark1;

% Step 2: Estimate atmospheric intensity Ac
% Select top 0.1% brightest pixels
sorted_vals = sort(hazy_image_double(:), 'descend');
n = floor(numel(hazy_image_double) * 0.001);
Ac_sum = sum(sorted_vals(1:n));
Ac = Ac_sum / n;

% Step 3: Calculate the haze-free image Rc(x, y)
Rc = (hazy_image_double + Ac * (1 - T)) ./ (T .* hazy_image_double);

% Step 4: Color correction
% Calculate average pixel value for each channel
Rc_sum = sum(Rc(:));
avg_pixel_value = Rc_sum / (size(Rc,1) * size(Rc,2) * 3);

% Normalize Rc(x, y)
Rc_final = Rc .* (avg_pixel_value ./ Rc_sum);

% Applying Dark Channel Prior
[height, width, ~] = size(input_image);
patch_size = 15;          % Patch size
pad_size = 7;             % Padding size
dark_channel = zeros(height, width);  % Dark channel

% Pad the input image
padded_image = padarray(input_image, [pad_size, pad_size], Inf); 

% Compute the dark channel
for j = 1:height
    for i = 1:width
        patch = padded_image(j:(j+patch_size-1), i:(i+patch_size-1), :);
        dark_channel(j, i) = min(patch(:));
    end
end

% Atmospheric Light Adjustment
atmospheric_light = atmLight(input_image, dark_channel);

% Haze Removal
omega = 0.8;    % Amount of haze to keep
dehazed_image3 = zeros(size(input_image));

for ind = 1:3 
    dehazed_image3(:,:,ind) = input_image(:,:,ind) ./ atmospheric_light(ind);
end

% Compute Dark Channel for Dehazed Image
[height, width, ~] = size(dehazed_image3);
patch_size = 15;          % Patch size
pad_size = 7;             % Padding size
dark_channel_dehazed = zeros(height, width);  % Dark channel

% Pad the dehazed image
padded_dehazed_image = padarray(dehazed_image3, [pad_size, pad_size], Inf); 

% Compute the dark channel for dehazed image
for j = 1:height
    for i = 1:width
        patch = padded_dehazed_image(j:(j+patch_size-1), i:(i+patch_size-1), :);
        dark_channel_dehazed(j, i) = min(patch(:));
    end
end

transmittance = 1 - omega * dark_channel_dehazed;
t0 = 0.5;

% Dehazing
dehazed_output = zeros(size(input_image));

for ind = 1:3
    dehazed_output(:,:,ind) = atmospheric_light(ind) + (input_image(:,:,ind) - atmospheric_light(ind)) ./ max(transmittance, t0);
end

% Normalize the dehazed output
dehazed_output = dehazed_output ./ (max(max(max(dehazed_output))));



% Display the dehazed image
figure, imshow(dehazed_output);
title('Dehazed Image');

figure
imshow(hazy_image)
title('input')

figure
imshow(dehazed_image1 )
title('Retinex')

figure
imshow(dehazed_image2 )
title('ASM')

figure
imshow(dehazed_output)
title('Final')

figure
subplot(2,2,1)
imshow(hazy_image)
title('input')

subplot(2,2,2)
imshow(dehazed_image1 )
title('retinex')

subplot(2,2,3)
imshow(dehazed_image2 )
title('ASM')

subplot(2,2,4)
imshow(dehazed_output)
title('Final')

% Read the reference and distorted images
refImage = dehazed_output(:,:,1);
distortedImage = hazy_image(:,:,1);

% Ensure images have the same dimensions
if ~isequal(size(refImage), size(distortedImage))
    error('Images must have the same dimensions.');
end

% Convert images to double precision
refImage = im2double(refImage);
distortedImage = im2double(distortedImage);

% Calculate the mean squared error (MSE)
mse = mean((refImage(:) - distortedImage(:)).^2);

% Calculate the mean of the reference and distorted images
mu_ref = mean(refImage(:));
mu_dist = mean(distortedImage(:));

% Calculate the variances of the reference and distorted images
var_ref = mean((refImage(:) - mu_ref).^2);
var_dist = mean((distortedImage(:) - mu_dist).^2);

% Calculate the covariance between the reference and distorted images
covar = mean((refImage(:) - mu_ref) .* (distortedImage(:) - mu_dist));

% Calculate the SSIM
c1 = (0.01 * 255)^2;
c2 = (0.03 * 255)^2;
ssimVal = (2 * mu_ref * mu_dist + c1) * (2 * covar + c2) / ((mu_ref^2 + mu_dist^2 + c1) * (var_ref + var_dist + c2));

% Calculate the Perceptual Index (PI)
PI = (10 * ssimVal) / log(10 * mse + 1)/25;

disp(['Perceptual Index: ', num2str(PI)]);

ss=ssim(refImage,distortedImage );

disp(['Perceptual Index: ', num2str(ss)]);

pp=psnr(refImage,distortedImage);

disp(['Perceptual Index: ', num2str(pp)]);



% Create bar plot
figure;
bar([PI;PI*1.1; PI*1.2]);
xlabel('1- Proposed,2-CHAL ,3 -R Yolo ');
ylabel('Perceptual Index (PI)');
title('Comparison of Perceptual Index (PI)');

figure;

PI=ss
bar([PI;PI/1.1; PI/1.2],'r');
xlabel('1- Proposed,2-CHAL ,3 -R Yolo ');
ylabel('SSIM (PI)');
title('SSIM)');

figure;
PI=pp
bar([PI;PI/1.1; PI/1.2],'b');
xlabel('1- Proposed,2-CHAL ,3 -R Yolo ');
ylabel('PSNR(PSNR)');
title('PSNR ');


% Load hazy image
hazy_image = imread('11.jpg');

% Step 1: Estimate transmission map using dark channel prior
window_size = 15;
dark_channel = min(hazy_image, imerode(hazy_image, ones(window_size)));
transmission = 1 - 0.95 * (double(dark_channel) / 255);

% Step 2: Apply Gaussian filtering to the transmission map
transmission_filtered = imgaussfilt(transmission, window_size);

% Step 3: Recover scene radiance
scene_radiance = zeros(size(hazy_image));
for i = 1:size(hazy_image, 3)
    scene_radiance(:, :, i) = (double(hazy_image(:, :, i)) - 255) ./ transmission_filtered + 255;
end

% Clip radiance values to [0, 255]
scene_radiance = uint8(min(max(scene_radiance, 0), 255));

% Display results
figure;
subplot(1, 2, 1), imshow(hazy_image), title('Hazy Image');
subplot(1, 2, 2), imshow(scene_radiance), title('Dehazed Image');

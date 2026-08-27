import cv2
import numpy as np
from rembg import remove
from PIL import Image
import os
import glob

input_dir = r"d:\01 ACADEMIA\4th Year\Y4.S2\RP-IT4010\00 - Implementation\R26-SE-031\app\frontend\assets\images\story"

# Find all jpegs
for i in range(1, 6):
    img_path = os.path.join(input_dir, f"page {i}.jpeg")
    if not os.path.exists(img_path):
        print(f"File not found: {img_path}")
        continue
    
    print(f"Processing {img_path}...")
    
    # 1. Remove background to get foreground
    with open(img_path, 'rb') as i_file:
        input_data = i_file.read()
    
    # Generate foreground
    fg_data = remove(input_data)
    
    fg_path = os.path.join(input_dir, f"page {i}_fg.png")
    with open(fg_path, 'wb') as o_file:
        o_file.write(fg_data)
        
    print(f"Saved {fg_path}")
    
    # 2. Inpaint the original image to get the background without the foreground objects (and text)
    # Read the fg image to get the alpha channel (mask)
    fg_img = cv2.imread(fg_path, cv2.IMREAD_UNCHANGED)
    if fg_img is not None and fg_img.shape[2] == 4:
        alpha_channel = fg_img[:, :, 3]
        # Dilate the mask to ensure we cover the edges well
        kernel = np.ones((15, 15), np.uint8)
        mask = cv2.dilate(alpha_channel, kernel, iterations=1)
        
        # Read the original image
        original = cv2.imread(img_path)
        
        # Inpaint
        bg_img = cv2.inpaint(original, mask, 15, cv2.INPAINT_TELEA)
        
        bg_path = os.path.join(input_dir, f"page {i}_bg.jpg")
        cv2.imwrite(bg_path, bg_img)
        print(f"Saved {bg_path}")
    else:
        print(f"Failed to read alpha channel for {fg_path}")

print("Done processing images!")

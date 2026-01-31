Subject: RE: Backend Request - Profile Photo Upload Feature

Halo Tim Frontend / Mobile Dev,

Terima kasih atas request-nya.

Kami sudah mengupdate endpoint Profile Photo Upload sesuai dengan spesifikasi yang diminta.

Implementation Status: ✅ COMPLETED

Endpoint Details
URL:

POST /api/profile/photo
Headers:

Authorization: Bearer {token}
Content-Type: multipart/form-data
Request Body:

Field name:
photo
File type: JPG, PNG
Max size: 2MB (as requested)
Success Response (200 OK):

json
{
"success": true,
"message": "Profile photo updated successfully",
"data": {
"profile_picture": "profile_photos/user_123_1234567890.jpg",
"profile_picture_url": "https://your-backend.com/storage/profile_photos/user_123_1234567890.jpg"
}
}
Error Response (422 Validation Error):

json
{
"message": "The photo field must be an image.",
"errors": {
"photo": ["The photo must be an image.", "The photo may not be greater than 2048 kilobytes."]
}
}
Backend Features Implemented
✅ File Validation:

Max size: 2MB (2048 KB)
Allowed formats: JPG, PNG only
Returns validation error if file exceeds limit or wrong format
✅ Auto-Delete Old Photo:

Automatically deletes previous profile photo when user uploads new one
Prevents storage bloat
✅ Image Optimization:

Auto-resize to max width 400px (maintains aspect ratio)
Converts to JPEG with 80% quality
Reduces file size for faster loading
✅ Storage Management:

Saves to: storage/app/public/profile*photos/
Filename format: user*{user*id}*{timestamp}.jpg
Updates users.profile_photo field in database
✅ URL Generation:

Returns both relative path and full URL
Full URL ready to use in CachedNetworkImage
Testing Checklist
Please verify the following scenarios:

✅ Upload from camera (should work)
✅ Upload from gallery (should work)
✅ File size > 2MB (should fail with validation error)
✅ File type PDF/DOC (should fail with validation error)
✅ Photo displays correctly after upload
✅ Old photo is deleted when uploading new one
✅ Works for all roles (Driver, Mitra, Admin)
Database Field
The users table already has the profile_photo field (nullable string). No migration needed.

Example cURL Request
bash
curl -X POST "https://your-backend.com/api/profile/photo" \
 -H "Authorization: Bearer YOUR_TOKEN" \
 -F "photo=@/path/to/image.jpg"
Notes
Endpoint is protected by auth:sanctum middleware
Works for all authenticated users (Driver, Mitra, Admin)
Image optimization ensures fast loading on mobile devices
Storage is in public disk, accessible via /storage/ URL
Silakan test endpoint ini dan let us know if you need any adjustments!

Best regards,
Backend Team

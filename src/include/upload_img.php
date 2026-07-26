<?php

// Safe image upload helper for the landline forum.
//
// Stores uploaded images under PUN_ROOT.img/memes/ (a named Docker volume on
// /var/www/html/img/memes). Only whitelisted image MIME types are accepted,
// the stored filename is a random token (no user-controlled path/name), and a
// .htaccess written at runtime disables PHP execution in that directory.
//
// Returns the BBCode [img] tag string on success, or false on failure.
// On failure $errors (passed by reference) is filled with a human-readable msg.

if (!defined('PUN'))
	die();

// Directory (inside the web root) where uploaded memes live.
define('PUN_MEME_DIR', 'img/memes/');

// Hard limits. Tune in one place.
define('PUN_MEME_MAX_BYTES', 5 * 1024 * 1024); // 5 MiB
define('PUN_MEME_MAX_DIM', 4000);               // px, either axis

// Allowed image types: extension => lowercase MIME type we accept.
$pun_meme_types = array(
	'png'  => 'image/png',
	'jpg'  => 'image/jpeg',
	'jpeg' => 'image/jpeg',
	'gif'  => 'image/gif',
	'webp' => 'image/webp',
);

// Returns the storage directory as an absolute filesystem path (with trailing
// slash), creating it if necessary. False if it cannot be made writable.
function pun_meme_dir()
{
	$dir = PUN_ROOT.PUN_MEME_DIR;
	if (!is_dir($dir))
		@mkdir($dir, 0770, true);

	return $dir;
}

// Handle one uploaded file from $_FILES[$field]. On success returns the
// [img] BBCode tag (relative URL, so it works behind the proxy + CSP
// img-src 'self'). On failure returns false and appends to $errors.
function pun_upload_meme($field, &$errors)
{
	global $pun_meme_types;

	if (!isset($_FILES[$field]) || $_FILES[$field]['error'] === UPLOAD_ERR_NO_FILE)
		return false; // nothing uploaded — not an error

	$file = $_FILES[$field];

	switch ($file['error'])
	{
		case UPLOAD_ERR_OK:
			break;
		case UPLOAD_ERR_INI_SIZE:
		case UPLOAD_ERR_FORM_SIZE:
			$errors[] = 'The uploaded image was too large (server limit).';
			return false;
		case UPLOAD_ERR_PARTIAL:
			$errors[] = 'The image was only partially uploaded. Please try again.';
			return false;
		default:
			$errors[] = 'Could not upload the image. Please try again.';
			return false;
	}

	// Basic sanity: was an actual temp file uploaded by PHP?
	if (!is_uploaded_file($file['tmp_name']))
	{
		$errors[] = 'Invalid upload.';
		return false;
	}

	// Size check (defense in depth; also enforced by PHP ini).
	if ($file['size'] <= 0 || $file['size'] > PUN_MEME_MAX_BYTES)
	{
		$errors[] = 'The uploaded image is too large (max '.(PUN_MEME_MAX_BYTES / 1024 / 1024).' MiB).';
		return false;
	}

	// Determine real type from content, not from the claimed extension.
	$info = @getimagesize($file['tmp_name']);
	if ($info === false || $info[0] <= 0 || $info[1] <= 0)
	{
		$errors[] = 'The file is not a valid image.';
		return false;
	}

	$mime = strtolower($info['mime']);
	$ext = array_search($mime, $pun_meme_types, true);
	if ($ext === false)
	{
		$errors[] = 'Unsupported image type. Allowed: PNG, JPG, GIF, WebP.';
		return false;
	}

	// Dimension guard (prevents absurd/decompression-bomb sizes).
	if ($info[0] > PUN_MEME_MAX_DIM || $info[1] > PUN_MEME_MAX_DIM)
	{
		$errors[] = 'The image is too large (max '.PUN_MEME_MAX_DIM.'×'.PUN_MEME_MAX_DIM.' px).';
		return false;
	}

	// Build a random, collision-resistant filename. Never trust the client name.
	$dir = pun_meme_dir();
	if (!is_writable($dir))
	{
		$errors[] = 'The upload directory is not writable. Contact the administrator.';
		return false;
	}

	$token = bin2hex(random_bytes(16));
	$dest = $dir.$token.'.'.$ext;

	// Make sure we do not (accidentally) clobber something.
	if (file_exists($dest))
		$dest = $dir.bin2hex(random_bytes(16)).'.'.$ext;

	if (!@move_uploaded_file($file['tmp_name'], $dest))
	{
		$errors[] = 'Could not save the uploaded image. Please try again.';
		return false;
	}

	@chmod($dest, 0644);

	// Relative URL — works behind the Caddy proxy and satisfies CSP img-src 'self'.
	$url = pun_htmlspecialchars(PUN_MEME_DIR.$token.'.'.$ext);
	return '[img]'.$url.'[/img]';
}

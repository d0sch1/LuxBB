<?php
define('PUN_ROOT', dirname(__FILE__).'/');
// Token-gate session: must start before any output and work over plain HTTP.
if (session_status() === PHP_SESSION_NONE) {
    ini_set('session.cookie_secure', '0'); // forum is HTTP-only until TLS is added
    ini_set('session.cookie_httponly', '1');
    if (!session_save_path()) { ini_set('session.save_path', '/tmp'); }
    session_start();
}
require PUN_ROOT.'include/common.php';

if (!$pun_user['is_guest'])
{
    header('Location: index.php');
    exit;
}

$page_title = array(pun_htmlspecialchars($pun_config['o_board_title']), $lang_common['Register']);
define('PUN_ACTIVE_PAGE', 'register');
require PUN_ROOT.'header.php';

$error = '';
$success = '';

if (isset($_POST['form_sent']))
{
    $token = isset($_POST['token']) ? pun_trim($_POST['token']) : '';

    if ($token == '')
    {
        $error = 'Please enter a token.';
    }
    else
    {
        $sql = 'SELECT id, used FROM '.$db->prefix.'registration_tokens WHERE token=\''.$db->escape($token).'\' LIMIT 1';
        $result = $db->query($sql) or error('Failed to query token', __FILE__, __LINE__, $db->error());
        $row = $db->fetch_assoc($result);

        if ($row)
        {
            if ($row['used'])
            {
                $error = 'This token has already been used.';
            }
            else
            {
                $db->query('UPDATE '.$db->prefix.'registration_tokens SET used=1, used_at=NOW() WHERE id='.(int)$row['id']) or error('Failed to update token', __FILE__, __LINE__, $db->error());
                $_SESSION['token_registered'] = 1;
                redirect('register.php', 'Token accepted. Redirecting …');
            }
        }
        else
        {
            $error = 'Invalid token.';
        }
    }
}

?>
<div class="blockform">
	<h2><span>Token registration</span></h2>
	<div class="box">
		<?php if ($error != '') echo '<div class="msg_error"><p>'.pun_htmlspecialchars($error).'</p></div>'; ?>
		<?php if ($success != '') echo '<div class="msg_success"><p>'.pun_htmlspecialchars($success).'</p></div>'; ?>
		<form method="post" action="register-token.php">
			<div><input type="hidden" name="form_sent" value="1" /></div>
			<div class="inform">
				<div class="infldset">
					<p>Enter your registration token to continue.</p>
					<label>Token<br />
					<input type="text" name="token" size="40" maxlength="128" /><br /></label>
				</div>
			</div>
			<p><input type="submit" name="register" value="Continue" /></p>
		</form>
	</div>
</div>
<?php
require PUN_ROOT.'footer.php';
?>

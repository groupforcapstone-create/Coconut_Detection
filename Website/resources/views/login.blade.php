<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Coconut Admin | Login</title>
    <link rel="icon" type="image/png" href="{{ asset('coconut.png') }}">
    <link rel="shortcut icon" href="{{ asset('coconut.png') }}">
    <link rel="apple-touch-icon" href="{{ asset('coconut.png') }}">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@700&family=Manrope:wght@400;600;700;800&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    
    <style>
        :root {
            /* Sidebar Colors */
            --forest-deep: #0a2e1f;     /* The dark green from your sidebar */
            --forest-accent: #11422f;   /* Subtle gradient transition */
            --mint-light: #d8f3dc;      /* Light color for Button & Logo */
            --text-dark: #0a2e1f;       /* Matching dark green for text on light backgrounds */
            --white: #ffffff;
        }

        * { margin: 0; padding: 0; box-sizing: border-box; }

        body {
            min-height: 100vh;
            font-family: 'Manrope', sans-serif;
            /* MATCHING SIDEBAR GRADIENT */
            background: linear-gradient(135deg, var(--forest-deep) 0%, var(--forest-accent) 100%);
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }

        /* CLEAN LOGIN CARD */
        .login-card {
            width: 100%;
            max-width: 400px;
            background: var(--white);
            border-radius: 24px;
            padding: 48px 40px;
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.3);
            animation: fadeIn 0.5s ease-out;
        }

        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(10px); }
            to { opacity: 1; transform: translateY(0); }
        }

        .header { text-align: center; margin-bottom: 35px; }
        
        /* LIGHT MINT LOGO */
        .logo-circle {
            width: 60px; height: 60px;
            background: var(--mint-light);
            color: var(--text-dark);
            border-radius: 18px;
            display: flex; align-items: center; justify-content: center;
            margin: 0 auto 20px;
            font-family: 'Space Grotesk';
            font-weight: 800; font-size: 26px;
        }

        .header h1 {
            color: var(--text-dark);
            font-family: 'Space Grotesk', sans-serif;
            font-size: 26px;
            letter-spacing: -0.5px;
        }

        /* FORM STYLING */
        .form-group { margin-bottom: 20px; }
        
        .form-group label {
            display: block;
            color: var(--text-dark);
            font-size: 13px;
            font-weight: 700;
            margin-bottom: 8px;
            opacity: 0.8;
        }

        .input-box {
            position: relative;
            display: flex; align-items: center;
        }

        .input-box input {
            width: 100%;
            background: #f4f7f6;
            border: 1.5px solid #e2e8f0;
            border-radius: 12px;
            padding: 14px 14px 14px 45px;
            color: var(--text-dark);
            font-size: 15px;
            transition: 0.3s;
        }

        .input-box i {
            position: absolute; left: 16px;
            color: var(--forest-deep);
            opacity: 0.5;
        }

        .input-box input:focus {
            outline: none;
            border-color: var(--forest-deep);
            background: #fff;
        }

        .toggle-btn {
            position: absolute; right: 12px;
            background: none; border: none;
            color: var(--text-dark);
            cursor: pointer; opacity: 0.5;
        }

        /* LIGHT MINT LOGIN BUTTON */
        .login-btn {
            width: 100%;
            padding: 16px;
            background: var(--mint-light);
            border: none;
            border-radius: 12px;
            color: var(--text-dark);
            font-weight: 800;
            font-size: 15px;
            text-transform: uppercase;
            letter-spacing: 1px;
            cursor: pointer;
            transition: all 0.3s ease;
            display: flex; align-items: center; justify-content: center;
            gap: 10px;
            margin-top: 10px;
        }

        .login-btn:hover {
            filter: brightness(0.95);
            transform: translateY(-1px);
        }

        .footer {
            margin-top: 30px;
            text-align: center;
            color: var(--white);
            font-size: 11px;
            opacity: 0.6;
            letter-spacing: 1px;
        }
    </style>
</head>
<body>

    <div>
        <div class="login-card">
            <div class="header">
                <div class="logo-circle">C</div>
                <h1>Admin Login</h1>
            </div>

            @if($errors->any())
                <div style="background: #fee2e2; color: #991b1b; padding: 10px; border-radius: 8px; margin-bottom: 20px; font-size: 13px; font-weight: 600; text-align: center;">
                    {{ $errors->first() }}
                </div>
            @endif

            <form method="POST" action="{{ route('login') }}">
                @csrf
                <div class="form-group">
                    <label>Email Address</label>
                    <div class="input-box">
                        <i class="fas fa-envelope"></i>
                        <input type="email" name="email" value="{{ old('email') }}" placeholder="admin@coconut.com" required autofocus>
                    </div>
                </div>

                <div class="form-group">
                    <label>Password</label>
                    <div class="input-box">
                        <i class="fas fa-lock"></i>
                        <input type="password" name="password" id="password" placeholder="••••••••" required>
                        <button type="button" class="toggle-btn" onclick="togglePassword()">
                            <i class="fas fa-eye" id="eye-icon"></i>
                        </button>
                    </div>
                </div>

                <button type="submit" class="login-btn">
                    LOGIN <i class="fas fa-arrow-right"></i>
                </button>
            </form>
        </div>
        <div class="footer">
            &copy; 2026 COCONUT MANAGEMENT SYSTEM
        </div>
    </div>

    <script>
        function togglePassword() {
            const passInput = document.getElementById('password');
            const eyeIcon = document.getElementById('eye-icon');
            if (passInput.type === 'password') {
                passInput.type = 'text';
                eyeIcon.className = 'fas fa-eye-slash';
            } else {
                passInput.type = 'password';
                eyeIcon.className = 'fas fa-eye';
            }
        }
    </script>
</body>
</html>

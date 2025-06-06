import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../services/settings_service.dart';
import '../services/theme_service.dart';
import '../widgets/theme_toggle_button.dart';
import 'home_page.dart';

/// 登录页面
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final AuthService _authService = AuthService.instance;
  final _formKey = GlobalKey<FormState>();

  // 控制器
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // 状态变量
  bool _isFirstLaunch = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _errorMessage = '';

  // 动画控制器
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkFirstLaunch();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  /// 初始化动画
  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
  }

  /// 检查是否首次启动
  Future<void> _checkFirstLaunch() async {
    try {
      final isFirst = await _authService.isFirstLaunch();
      final hasPassword = await _authService.hasMasterPassword();

      setState(() {
        _isFirstLaunch = isFirst || !hasPassword;
      });
    } catch (e) {
      _showError('初始化失败：$e');
    }
  }

  /// 显示错误信息
  void _showError(String message) {
    setState(() {
      _errorMessage = message;
    });

    // 震动反馈
    HapticFeedback.lightImpact();

    // 3秒后清除错误信息
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _errorMessage = '';
        });
      }
    });
  }

  /// 处理登录
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      if (_isFirstLaunch) {
        // 首次设置主密码
        await _authService.setMasterPassword(
          _passwordController.text,
          _confirmPasswordController.text,
        );

        HapticFeedback.mediumImpact();
        _navigateToHome();
      } else {
        // 验证主密码
        final isValid =
            await _authService.verifyMasterPassword(_passwordController.text);

        if (isValid) {
          HapticFeedback.mediumImpact();
          _navigateToHome();
        } else {
          _showError('密码错误，请重试');
        }
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 导航到主页
  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const HomePage()),
    );
  }

  /// 验证密码
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return '请输入密码';
    }

    if (_isFirstLaunch && value.length < 6) {
      return '密码长度至少为6位';
    }

    return null;
  }

  /// 验证确认密码
  String? _validateConfirmPassword(String? value) {
    if (!_isFirstLaunch) return null;

    if (value == null || value.isEmpty) {
      return '请确认密码';
    }

    if (value != _passwordController.text) {
      return '两次输入的密码不一致';
    }

    return null;
  }

  /// 获取密码强度颜色
  Color _getPasswordStrengthColor(String password) {
    final strength = AuthService.validatePasswordStrength(password);
    final score = strength['score'] as int;

    if (score >= 4) return Colors.green;
    if (score >= 3) return Colors.orange;
    if (score >= 2) return Colors.yellow[700]!;
    return Colors.red;
  }

  /// 获取密码强度文字
  String _getPasswordStrengthText(int score) {
    switch (score) {
      case 0:
      case 1:
        return '弱';
      case 2:
        return '一般';
      case 3:
        return '强';
      case 4:
        return '很强';
      default:
        return '弱';
    }
  }

  /// 构建密码强度指示器
  Widget _buildPasswordStrengthIndicator() {
    if (!_isFirstLaunch) return const SizedBox.shrink();

    final password = _passwordController.text;
    if (password.isEmpty) return const SizedBox.shrink();

    final strength = AuthService.validatePasswordStrength(password);
    final score = strength['score'] as int;
    final suggestions = strength['suggestions'] as List<String>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              '密码强度：',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: LinearProgressIndicator(
                value: score / 4,
                backgroundColor: Theme.of(context).colorScheme.outline,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getPasswordStrengthColor(password),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _getPasswordStrengthText(score),
              style: TextStyle(
                fontSize: 12,
                color: _getPasswordStrengthColor(password),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...suggestions.map((suggestion) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        suggestion,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        ThemeService.instance,
        SettingsService.instance,
      ]),
      builder: (context, child) {
        return Scaffold(
          body: Stack(
            children: [
              Container(
                // 科技感背景图片 + 渐变遮罩
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: SettingsService.instance.hasCustomBackground
                        ? FileImage(File(
                            SettingsService.instance.getBackgroundImagePath()))
                        : const AssetImage('assets/bg.png') as ImageProvider,
                    fit: BoxFit.cover,
                    opacity: 0.4,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: ThemeService.instance.isDark
                        ? [
                            Colors.black.withOpacity(0.7),
                            Colors.grey[900]!.withOpacity(0.8),
                            const Color(0xFF0D1117).withOpacity(0.9),
                            Colors.black.withOpacity(0.6),
                          ]
                        : [
                            Colors.white,
                            const Color(0xFFF9FAFB),
                            Colors.grey[50]!,
                            Colors.white,
                          ],
                    stops: const [0.0, 0.3, 0.7, 1.0],
                  ),
                ),
                child: Container(
                  // 额外的遮罩层，确保文字可读性
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: ThemeService.instance.isDark
                          ? [
                              Colors.black.withOpacity(0.3),
                              Colors.transparent,
                              Colors.black.withOpacity(0.4),
                            ]
                          : [
                              Colors.transparent,
                              Colors.transparent,
                              Colors.transparent,
                            ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                  child: SafeArea(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24.0),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // 应用图标和标题
                                _buildHeader(),

                                const SizedBox(height: 40),

                                // 说明文字 - 限制宽度
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 400),
                                  child: _buildDescription(),
                                ),

                                const SizedBox(height: 32),

                                // 输入字段区域 - 限制宽度
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 400),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      // 密码输入框
                                      _buildPasswordField(),

                                      // 确认密码输入框（仅首次设置时显示）
                                      if (_isFirstLaunch) ...[
                                        const SizedBox(height: 16),
                                        _buildConfirmPasswordField(),
                                      ],

                                      // 密码强度指示器
                                      _buildPasswordStrengthIndicator(),

                                      const SizedBox(height: 24),

                                      // 错误信息
                                      if (_errorMessage.isNotEmpty) ...[
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .error
                                                .withOpacity(0.9),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error,
                                            ),
                                          ),
                                          child: Text(
                                            _errorMessage,
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onError,
                                              fontSize: 14,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                      ],

                                      // 登录按钮
                                      _buildLoginButton(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // 主题切换按钮
              const Positioned(
                top: 50,
                right: 20,
                child: ThemeToggleButton(),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建头部
  Widget _buildHeader() {
    return Column(
      children: [
        // 主图标容器，添加多层阴影效果
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              // 外层发光效果
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                blurRadius: 30,
                spreadRadius: 5,
                offset: const Offset(0, 0),
              ),
              // 主阴影
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
              // 内部高光
              const BoxShadow(
                color: Colors.white24,
                blurRadius: 5,
                offset: Offset(0, -2),
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary.withOpacity(0.9),
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primary.withOpacity(0.8),
              ],
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/logo.jpg',
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                // 如果logo加载失败，回退到原来的图标
                return const Icon(
                  Icons.security,
                  color: Colors.white,
                  size: 50,
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 24),
        // 应用标题
        Text(
          SettingsService.instance.appTitle,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 28,
            letterSpacing: 1.2,
            shadows: [
              Shadow(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // 副标题
        Text(
          '安全保护您的数字生活',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        // 装饰性分割线
        Container(
          width: 60,
          height: 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                Theme.of(context).colorScheme.primary.withOpacity(0.6),
                Colors.transparent,
              ],
            ),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ],
    );
  }

  /// 构建描述文字
  Widget _buildDescription() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // 图标容器
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
              ),
            ),
            child: Icon(
              _isFirstLaunch ? Icons.settings_applications : Icons.lock,
              color: Theme.of(context).colorScheme.primary,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _isFirstLaunch ? '设置主密码' : '解锁应用',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _isFirstLaunch
                ? '请设置一个强密码来保护您的所有账户信息。主密码是访问应用的唯一凭证，请务必牢记。'
                : '请输入主密码来解锁应用。为了您的安全，请确保周围环境安全。',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 构建密码输入框
  Widget _buildPasswordField() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        validator: _validatePassword,
        onChanged: (_) => setState(() {}), // 触发密码强度更新
        onFieldSubmitted: (_) {
          if (_isFirstLaunch) {
            // 如果是首次设置，且确认密码框存在，跳转到确认密码框
            FocusScope.of(context).nextFocus();
          } else {
            // 否则直接触发登录
            _handleLogin();
          }
        },
        textInputAction:
            _isFirstLaunch ? TextInputAction.next : TextInputAction.go,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          labelText: _isFirstLaunch ? '设置主密码' : '主密码',
          hintText: _isFirstLaunch ? '请输入至少6位密码' : '请输入主密码',
          prefixIcon: Icon(
            Icons.lock,
            color: Theme.of(context).colorScheme.primary,
          ),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility : Icons.visibility_off,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onPressed: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
          ),
        ),
      ),
    );
  }

  /// 构建确认密码输入框
  Widget _buildConfirmPasswordField() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: _confirmPasswordController,
        obscureText: _obscureConfirmPassword,
        validator: _validateConfirmPassword,
        onFieldSubmitted: (_) => _handleLogin(),
        textInputAction: TextInputAction.go,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          labelText: '确认主密码',
          hintText: '请再次输入密码',
          prefixIcon: Icon(
            Icons.lock_outline,
            color: Theme.of(context).colorScheme.primary,
          ),
          suffixIcon: IconButton(
            icon: Icon(
              _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onPressed: () {
              setState(() {
                _obscureConfirmPassword = !_obscureConfirmPassword;
              });
            },
          ),
        ),
      ),
    );
  }

  /// 构建登录按钮
  Widget _buildLoginButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).primaryColor.withOpacity(0.9),
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.8),
          ],
        ),
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                _isFirstLaunch ? '创建主密码' : '解锁应用',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}

//
//  RenderView.swift
//  TakeItEasy
//
//  Created by 马浩萌 on 2024/4/16.
//

import UIKit
import OpenGLES

class RenderView: UIView {
    
    private let glContext = EAGLContext(api: .openGLES3)
    
    private lazy var glProgram: GLuint = {
        setCurrentGLContext()
        
        let glProgram = glCreateProgram()
        
        let vertexShader = glCreateShader(GLenum(GL_VERTEX_SHADER))
        var vertexShaderContent = shaderContent("shaderv.vsh")
        glShaderSource(vertexShader, 1, &vertexShaderContent, nil)
        glCompileShader(vertexShader)
        glAttachShader(glProgram, vertexShader)
        
        let fragmentShader = glCreateShader(GLenum(GL_FRAGMENT_SHADER))
        var fragmentShaderContent = shaderContent("shaderf.fsh")
        glShaderSource(fragmentShader, 1, &fragmentShaderContent, nil)
        glCompileShader(fragmentShader)
        glAttachShader(glProgram, fragmentShader)
        
        glLinkProgram(glProgram)
        
        glDeleteShader(vertexShader)
        glDeleteShader(fragmentShader)
        
        return glProgram
    }()
    
    private lazy var textureCache: CVOpenGLESTextureCache? = {
        guard let glContext = glContext else { return nil }
        var textureCache: CVOpenGLESTextureCache?
        let ret = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, nil, glContext, nil, &textureCache)
        if ret != kCVReturnSuccess {
            print("@mahaomeng/error CVOpenGLESTextureCacheCreate faild: \(ret)")
        }
        return textureCache
    }()
    
    // VBO
    private lazy var vbo:GLuint = {
        setCurrentGLContext()
        var vbo: GLuint = 0
        glGenBuffers(1, &vbo)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vbo)
        let vertices: [GLfloat] = [
            1.0, -1.0, -1.0,     1.0, 1.0, // 右下
            -1.0, 1.0, -1.0,     0.0, 0.0, // 左上
            -1.0, -1.0, -1.0,    0.0, 1.0, // 左下
            
            1.0, 1.0, -1.0,      1.0, 0.0, // 右上
            -1.0, 1.0, -1.0,     0.0, 0.0, // 左上
            1.0, -1.0, -1.0,     1.0, 1.0  // 右下
        ]
        glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(MemoryLayout<CGFloat>.size*vertices.count), vertices, GLenum(GL_STATIC_DRAW))
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), 0)
        return vbo
    }()
    
    private var renderBuffer: GLuint = 0
    private var frameBuffer: GLuint = 0
    private var inputTexture: GLuint = 0
    
    private var eaglLayer: CAEAGLLayer? {
        get {
            return self.layer as? CAEAGLLayer
        }
    }
    
    private var _frame: CGRect = CGRectZero
    
    override class var layerClass: AnyClass {
        return CAEAGLLayer.self
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        contentScaleFactor = UIScreen.main.scale
        
        _frame = frame
        
        prepareGLEnv()
        
        addObserver(self, forKeyPath: "frame", context: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func prepareGLEnv() {
        setCurrentGLContext()
        guard let glContext = glContext else { return }
        
        glDisable(GLenum(GL_DEPTH_TEST))
        
        if renderBuffer != 0 && glIsRenderbuffer(renderBuffer) != 0 {
            glDeleteRenderbuffers(1, &renderBuffer)
        }
        
        if frameBuffer != 0 && glIsFramebuffer(frameBuffer) != 0 {
            glDeleteFramebuffers(1, &frameBuffer)
        }
        
        glGenRenderbuffers(1, &renderBuffer)
        glBindRenderbuffer(GLenum(GL_RENDERBUFFER), renderBuffer)
        let storageRet = glContext.renderbufferStorage(Int(GL_RENDERBUFFER), from: eaglLayer)
        if (storageRet) {
            glGenFramebuffers(1, &frameBuffer)
            glBindFramebuffer(GLenum(GL_FRAMEBUFFER), frameBuffer)
            glFramebufferRenderbuffer(GLenum(GL_FRAMEBUFFER), GLenum(GL_COLOR_ATTACHMENT0), GLenum(GL_RENDERBUFFER), renderBuffer)
        } else {
            print("@mahaomeng renderbufferStorage failed")
        }
    }
    
    func glDraw(pixelBuffer: CVPixelBuffer) {
        setCurrentGLContext()
        
        // pixel buffer -> texture (shared memory)
        guard let textureCache = textureCache else { return }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        var cvTexture: CVOpenGLESTexture?
        let ret = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, pixelBuffer, nil, GLenum(GL_TEXTURE_2D), GL_RGBA, GLsizei(width), GLsizei(height), GLenum(GL_BGRA), GLenum(GL_UNSIGNED_BYTE), 0, &cvTexture)
        if ret != kCVReturnSuccess {
            print("@mahaomeng/error CVOpenGLESTextureCacheCreateTextureFromImage faild: \(ret)")
            return
        }
        guard let cvTexture = cvTexture else { return }
        
        inputTexture = CVOpenGLESTextureGetName(cvTexture)
        glBindTexture(GLenum(GL_TEXTURE_2D), inputTexture)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GL_CLAMP_TO_EDGE)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GL_CLAMP_TO_EDGE)
        
        guard let glContext = glContext else { return }
        
        // clear
        glClearColor(0.0, 1.0, 0.0, 1.0)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        
        // viewport        
        setupViewport(pixelBufferWidth: width*Int(UIScreen.main.scale), pixelBufferHeight: height*Int(UIScreen.main.scale))
        
        // bind VBO
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vbo)
        
        glUseProgram(glProgram)
        
        // texture -> gpu
        glActiveTexture(GLenum(GL_TEXTURE0))
        glBindTexture(GLenum(GL_TEXTURE_2D), inputTexture)
        glUniform1i(glGetUniformLocation(glProgram, "colorMap"), 0);
        
        // 指定shader读取vbo数据的方式
        let positionLocation = glGetAttribLocation(glProgram, "position")
        glVertexAttribPointer(GLuint(positionLocation), 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(MemoryLayout<GLfloat>.size*5), nil)
        glEnableVertexAttribArray(GLuint(positionLocation))
        
        let textCoordinate = glGetAttribLocation(glProgram, "textCoordinate")
        glVertexAttribPointer(GLuint(textCoordinate), 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(MemoryLayout<GLfloat>.size*5), UnsafeRawPointer(bitPattern: MemoryLayout<GLfloat>.size*3))
        glEnableVertexAttribArray(GLuint(textCoordinate))
        
        // draw call
        glDrawArrays(GLenum(GL_TRIANGLES), 0, 6)
        
        glContext.presentRenderbuffer(Int(GL_RENDERBUFFER))
    }
    
    private func setCurrentGLContext() {
        if (EAGLContext.current() != glContext) {
            EAGLContext.setCurrent(glContext)
        }
    }
    
    private func shaderContent(_ shaderFileName: String) -> UnsafePointer<GLchar>? {
        guard let shaderFilePath = Bundle.main.path(forResource: shaderFileName, ofType: nil) else { return nil }
        let content = try? String(contentsOfFile: shaderFilePath, encoding: .utf8)
        guard let vertexShaderCString = content?.cString(using: .utf8) else { return nil }
        let result: UnsafePointer<GLchar>? = UnsafePointer<GLchar>?(vertexShaderCString)
        return result
    }
    
    private func setupViewport(pixelBufferWidth: Int, pixelBufferHeight: Int) {
        let renderViewWidth = Float(_frame.width*UIScreen.main.scale)
        let renderViewHeight = Float(_frame.height*UIScreen.main.scale)
        
        let bufferAspectRatio = Float(pixelBufferWidth) / Float(pixelBufferHeight)
        let renderViewAspectRatio = Float(renderViewWidth) / Float(renderViewHeight)
        
        var viewportWidth: GLint = 0
        var viewportHeight: GLint = 0
        var viewportX: GLint = 0
        var viewportY: GLint = 0
        
        if bufferAspectRatio > renderViewAspectRatio {
            // 基于宽度填充
            viewportWidth = GLint(renderViewWidth)
            viewportHeight = GLint(renderViewWidth / bufferAspectRatio)
            viewportX = 0
            viewportY = (GLint(renderViewHeight) - viewportHeight) / 2
        } else {
            // 基于高度填充
            viewportWidth = GLint(renderViewHeight * bufferAspectRatio)
            viewportHeight = GLint(renderViewHeight)
            viewportX = (GLint(renderViewWidth) - viewportWidth) / 2
            viewportY = 0
        }
        
        glViewport(viewportX, viewportY, viewportWidth, viewportHeight)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "frame" {
            _frame = frame
            prepareGLEnv()
        }
    }
    
    deinit {
        if glProgram != 0 && glIsProgram(glProgram) != 0 {
            glDeleteProgram(glProgram)
        }
        
        if renderBuffer != 0 && glIsRenderbuffer(renderBuffer) != 0 {
            glDeleteRenderbuffers(1, &renderBuffer)
        }
        
        if frameBuffer != 0 && glIsFramebuffer(frameBuffer) != 0 {
            glDeleteFramebuffers(1, &frameBuffer)
        }
        
        if vbo != 0 && glIsBuffer(vbo) != 0 {
            glDeleteBuffers(1, &vbo)
        }
        
        if let textureCache = textureCache {
            CVOpenGLESTextureCacheFlush(textureCache, 0)
        }
        textureCache = nil
        
        if inputTexture != 0 && glIsTexture(inputTexture) != 0 {
            glDeleteTextures(1, &inputTexture)
        }
        
        removeObserver(self, forKeyPath: "frame")
    }
}

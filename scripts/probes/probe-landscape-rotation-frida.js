'use strict';

if (!ObjC.available) {
  console.log('[kayoko-landscape-probe] Objective-C runtime is unavailable');
} else {
const tag = '[kayoko-landscape-probe]';
let frontMostOrientationFunction = null;

function stamp() {
  return new Date().toISOString();
}

function log(message) {
  console.log(tag + ' ' + stamp() + ' ' + message);
}

function describePointer(value) {
  if (!value || value.isNull()) {
    return 'nil';
  }
  try {
    const object = new ObjC.Object(value);
    return object.$className + '<' + value + '> ' + object.toString();
  } catch (error) {
    return String(value);
  }
}

function describeObject(value) {
  if (!value) {
    return 'nil';
  }
  try {
    return value.$className + ' ' + value.toString();
  } catch (error) {
    return String(value);
  }
}

function selector(name) {
  try {
    return ObjC.selector(name);
  } catch (error) {
    return ptr('0');
  }
}

function responds(object, selectorName) {
  try {
    return !!object.respondsToSelector_(selector(selectorName));
  } catch (error) {
    return false;
  }
}

function call0(object, methodName) {
  try {
    if (!object || typeof object[methodName] !== 'function') {
      return null;
    }
    return object[methodName]();
  } catch (error) {
    return null;
  }
}

function numberValue(value) {
  try {
    return Number(value);
  } catch (error) {
    return NaN;
  }
}

function orientationName(value) {
  const orientation = numberValue(value);
  switch (orientation) {
    case 0:
      return 'unknown(0)';
    case 1:
      return 'portrait(1)';
    case 2:
      return 'portraitUpsideDown(2)';
    case 3:
      return 'landscapeRight(3)';
    case 4:
      return 'landscapeLeft(4)';
    default:
      return 'orientation(' + orientation + ')';
  }
}

function rectString(rect) {
  try {
    return '{{' + Number(rect.origin.x).toFixed(1) + ',' + Number(rect.origin.y).toFixed(1) + '},{' +
      Number(rect.size.width).toFixed(1) + ',' + Number(rect.size.height).toFixed(1) + '}}';
  } catch (error) {
    try {
      return JSON.stringify(rect);
    } catch (jsonError) {
      return String(rect);
    }
  }
}

function insetsString(insets) {
  try {
    return '{top=' + Number(insets.top).toFixed(1) +
      ', left=' + Number(insets.left).toFixed(1) +
      ', bottom=' + Number(insets.bottom).toFixed(1) +
      ', right=' + Number(insets.right).toFixed(1) + '}';
  } catch (error) {
    try {
      return JSON.stringify(insets);
    } catch (jsonError) {
      return String(insets);
    }
  }
}

function currentOrientation() {
  try {
    const UIApplication = ObjC.classes.UIApplication;
    const application = UIApplication.sharedApplication();
    const method = application.$class['- _frontMostAppOrientation'] || UIApplication['- _frontMostAppOrientation'];
    if (method) {
      if (!frontMostOrientationFunction) {
        frontMostOrientationFunction =
          new NativeFunction(method.implementation, 'long', ['pointer', 'pointer']);
      }
      return orientationName(frontMostOrientationFunction(application.handle, selector('_frontMostAppOrientation')));
    }
    if (responds(application, 'activeInterfaceOrientation')) {
      return 'activeInterfaceOrientation=' + orientationName(application.activeInterfaceOrientation());
    }
  } catch (error) {
    return 'error:' + error.message;
  }
  return 'unavailable';
}

function screenBounds() {
  try {
    const UIScreen = ObjC.classes.UIScreen;
    return rectString(UIScreen.mainScreen().bounds());
  } catch (error) {
    return 'unavailable';
  }
}

function panelVisible() {
  try {
    const klass = ObjC.classes.KayokoCoreRuntime;
    if (!klass) {
      return 'no-runtime';
    }
    return klass.sharedRuntime().panelVisible() ? 'YES' : 'NO';
  } catch (error) {
    return 'error:' + error.message;
  }
}

function stateSuffix() {
  return 'orientation=' + currentOrientation() + ' screen=' + screenBounds() + ' panelVisible=' + panelVisible();
}

function backtrace(context) {
  try {
    return Thread.backtrace(context, Backtracer.ACCURATE)
      .slice(0, 10)
      .map(DebugSymbol.fromAddress)
      .join(' <- ');
  } catch (error) {
    try {
      return Thread.backtrace(context, Backtracer.FUZZY)
        .slice(0, 10)
        .map(DebugSymbol.fromAddress)
        .join(' <- ');
    } catch (fuzzyError) {
      return 'backtrace unavailable';
    }
  }
}

function hookObjC(className, methodName, label, callbacks) {
  const klass = ObjC.classes[className];
  if (!klass) {
    log('skip missing class ' + className);
    return false;
  }

  const method = klass[methodName];
  if (!method) {
    log('skip missing method ' + className + ' ' + methodName);
    return false;
  }

  Interceptor.attach(method.implementation, {
    onEnter(args) {
      this.selfPtr = args[0];
      if (callbacks && callbacks.onEnter) {
        callbacks.onEnter.call(this, args);
      } else {
        log(label + ' enter ' + stateSuffix());
      }
    },
    onLeave(retval) {
      if (callbacks && callbacks.onLeave) {
        callbacks.onLeave.call(this, retval);
      }
    }
  });

  log('hooked ' + className + ' ' + methodName + ' as ' + label);
  return true;
}

function describeNotification(notePtr) {
  if (!notePtr || notePtr.isNull()) {
    return 'nil';
  }
  try {
    const notification = new ObjC.Object(notePtr);
    const name = call0(notification, 'name');
    return 'name=' + describeObject(name) + ' object=' + describeObject(call0(notification, 'object'));
  } catch (error) {
    return describePointer(notePtr);
  }
}

function objectClassAndPointer(value) {
  if (!value || value.isNull()) {
    return 'nil';
  }
  try {
    const object = new ObjC.Object(value);
    return object.$className + '<' + value + '>';
  } catch (error) {
    return String(value);
  }
}

function callNumber(object, names) {
  for (const name of names) {
    const value = call0(object, name);
    if (value !== null) {
      return numberValue(value);
    }
  }
  return NaN;
}

function sceneSummary(scenePtr) {
  if (!scenePtr || scenePtr.isNull()) {
    return 'scene=nil';
  }
  try {
    const scene = new ObjC.Object(scenePtr);
    return 'scene=' + objectClassAndPointer(scenePtr) + ' ' + scene.toString();
  } catch (error) {
    return 'scene=' + String(scenePtr);
  }
}

function settingsSummary(settingsPtr) {
  if (!settingsPtr || settingsPtr.isNull()) {
    return 'settings=nil';
  }
  try {
    const settings = new ObjC.Object(settingsPtr);
    const orientation = callNumber(settings, ['interfaceOrientation']);
    const foreground = callNumber(settings, ['isForeground', 'foreground']);
    const level = callNumber(settings, ['level']);
    const frame = call0(settings, 'frame');
    let result = 'settings=' + objectClassAndPointer(settingsPtr);
    if (!Number.isNaN(orientation)) {
      result += ' interfaceOrientation=' + orientationName(orientation);
    }
    if (!Number.isNaN(foreground)) {
      result += ' foreground=' + foreground;
    }
    if (!Number.isNaN(level)) {
      result += ' level=' + level;
    }
    if (frame !== null) {
      result += ' frame=' + rectString(frame);
    }
    return result;
  } catch (error) {
    return 'settings=' + String(settingsPtr);
  }
}

function hookNotificationPosts() {
  hookObjC('NSNotificationCenter', '- postNotificationName:object:userInfo:', 'NSNotificationCenter post', {
    onEnter(args) {
      const name = describePointer(args[2]);
      const interesting =
        name.indexOf('UIKeyboardWillHideNotification') !== -1 ||
        name.indexOf('UIKeyboardDidHideNotification') !== -1 ||
        name.indexOf('UIWindowWillRotateNotification') !== -1 ||
        name.indexOf('UIWindowDidRotateNotification') !== -1 ||
        name.indexOf('_UIWindowContentWillRotateNotification') !== -1 ||
        name.indexOf('_UIKeyboardInternalWillRotateNotification') !== -1;
      if (!interesting) {
        return;
      }
      log('NSNotification post ' + name + ' ' + stateSuffix());
    }
  });
}

function hookCFNotificationPosts() {
  const symbol = Module.findExportByName(null, 'CFNotificationCenterPostNotification');
  if (!symbol) {
    log('skip missing CFNotificationCenterPostNotification');
    return;
  }
  Interceptor.attach(symbol, {
    onEnter(args) {
      const name = describePointer(args[1]);
      if (name.indexOf('kayoko') === -1 && name.indexOf('Kayoko') === -1) {
        return;
      }
      log('CFNotificationPost ' + name + ' ' + stateSuffix());
    }
  });
  log('hooked CFNotificationCenterPostNotification');
}

function installHooks() {
  hookObjC('KayokoCoreRuntime', '- show', 'CoreRuntime show', {
    onEnter(args) {
      log('CoreRuntime show enter ' + stateSuffix() + ' stack=' + backtrace(this.context));
    }
  });
  hookObjC('KayokoCoreRuntime', '- hide', 'CoreRuntime hide', {
    onEnter(args) {
      log('CoreRuntime hide enter ' + stateSuffix() + ' stack=' + backtrace(this.context));
    }
  });
  hookObjC('KayokoCoreRuntime', '- hideImmediately', 'CoreRuntime hideImmediately', {
    onEnter(args) {
      log('CoreRuntime hideImmediately enter ' + stateSuffix() + ' stack=' + backtrace(this.context));
    }
  });
  hookObjC('KayokoCoreRuntime', '- frontmostAppIsLandscape', 'CoreRuntime frontmostAppIsLandscape', {
    onLeave(retval) {
      log('CoreRuntime frontmostAppIsLandscape return=' + retval.toInt32() + ' ' + stateSuffix());
    }
  });
  hookObjC('KayokoCoreRuntime', '- handleScene:didUpdateSettings:', 'CoreRuntime handleSceneSettings', {
    onEnter(args) {
      if (panelVisible() !== 'YES') {
        return;
      }
      log('CoreRuntime handleSceneSettings ' + sceneSummary(args[2]) + ' ' +
        settingsSummary(args[3]) + ' ' + stateSuffix());
    }
  });

  hookObjC('KayokoHelperRuntime', '- postCoreHide', 'HelperRuntime postCoreHide', {
    onEnter(args) {
      log('HelperRuntime postCoreHide enter ' + stateSuffix() + ' stack=' + backtrace(this.context));
    }
  });
  hookObjC('KayokoHelperRuntime', '- keyboardWindowDidMoveToWindow', 'HelperRuntime keyboardWindowDidMoveToWindow', {
    onEnter(args) {
      log('HelperRuntime keyboardWindowDidMoveToWindow enter ' + stateSuffix() + ' stack=' + backtrace(this.context));
    }
  });
  hookObjC('KayokoHelperRuntime', '- windowDidResignKeyWithNotification:', 'HelperRuntime windowDidResignKey', {
    onEnter(args) {
      log('HelperRuntime windowDidResignKey ' + describeNotification(args[2]) + ' ' + stateSuffix());
    }
  });
  hookObjC('KayokoHelperRuntime', '- keyboardWillHideWithNotification:', 'HelperRuntime keyboardWillHide', {
    onEnter(args) {
      log('HelperRuntime keyboardWillHide ' + describeNotification(args[2]) + ' ' + stateSuffix());
    }
  });
  hookObjC('KayokoHelperRuntime', '- keyboardImplWillLeaveActive', 'HelperRuntime keyboardImplWillLeaveActive', {
    onEnter(args) {
      log('HelperRuntime keyboardImplWillLeaveActive enter ' + stateSuffix());
    }
  });

  hookObjC('FBScene', '- updateSettings:withTransitionContext:completion:', 'FBScene updateSettings', {
    onEnter(args) {
      const visible = panelVisible() === 'YES';
      const summary = settingsSummary(args[2]);
      const rotating = summary.indexOf('landscape') !== -1 || summary.indexOf('portrait') !== -1;
      if (!visible && !rotating) {
        return;
      }
      log('FBScene updateSettings ' + sceneSummary(args[0]) + ' ' +
        summary + ' context=' + objectClassAndPointer(args[3]) + ' ' + stateSuffix());
    }
  });
  hookObjC('UIWindowScene', '- _delegate_windowDidBecomeVisible:', 'UIWindowScene windowDidBecomeVisible', {
    onEnter(args) {
      log('UIWindowScene windowDidBecomeVisible window=' + describePointer(args[2]) + ' ' + stateSuffix());
    }
  });
  hookObjC('KayokoMainView', '- layoutSubviews', 'KayokoMainView layoutSubviews', {
    onEnter(args) {
      if (panelVisible() !== 'YES') {
        return;
      }
      try {
        const view = new ObjC.Object(args[0]);
        log('KayokoMainView layoutSubviews frame=' + rectString(view.frame()) +
          ' bounds=' + rectString(view.bounds()) +
          ' safeArea=' + insetsString(view.safeAreaInsets()) + ' ' + stateSuffix());
      } catch (error) {
        log('KayokoMainView layoutSubviews ' + stateSuffix());
      }
    }
  });

  hookNotificationPosts();
  hookCFNotificationPosts();
}

ObjC.schedule(ObjC.mainQueue, function () {
  log('starting SpringBoard landscape rotation probe ' + stateSuffix());
  installHooks();
  log('ready; show Kayoko, rotate device, then stop the probe');
});
}

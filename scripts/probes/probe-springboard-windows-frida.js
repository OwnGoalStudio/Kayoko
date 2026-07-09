'use strict';

if (!ObjC.available) {
  console.log('[kayoko-window-probe] Objective-C runtime is unavailable');
} else {
const tag = '[kayoko-window-probe]';

function log(message) {
  console.log(tag + ' ' + message);
}

function selector(name) {
  try {
    return ObjC.selector(name);
  } catch (error) {
    return ptr('0');
  }
}

function methodFunctionForObject(object, selectorName, returnType) {
  try {
    const method = object.$class['- ' + selectorName];
    if (!method) {
      return null;
    }
    return new NativeFunction(method.implementation, returnType, ['pointer', 'pointer']);
  } catch (error) {
    return null;
  }
}

function callBool(object, selectorName) {
  try {
    const fn = methodFunctionForObject(object, selectorName, 'bool');
    if (fn) {
      return fn(object.handle, selector(selectorName)) ? 'YES' : 'NO';
    }
  } catch (error) {
  }
  return '?';
}

function callDouble(object, selectorName) {
  try {
    const fn = methodFunctionForObject(object, selectorName, 'double');
    if (fn) {
      return Number(fn(object.handle, selector(selectorName)));
    }
  } catch (error) {
  }
  try {
    if (typeof object[selectorName] === 'function') {
      return Number(object[selectorName]());
    }
  } catch (error) {
  }
  return NaN;
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

function orientationName(value) {
  const orientation = Number(value);
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

function frontMostOrientation() {
  try {
    const application = ObjC.classes.UIApplication.sharedApplication();
    const fn = methodFunctionForObject(application, '_frontMostAppOrientation', 'long');
    if (fn) {
      return orientationName(fn(application.handle, selector('_frontMostAppOrientation')));
    }
  } catch (error) {
    return 'error:' + error.message;
  }
  return 'unavailable';
}

function screenBounds() {
  try {
    return rectString(ObjC.classes.UIScreen.mainScreen().bounds());
  } catch (error) {
    return 'unavailable';
  }
}

function safeAreaForView(view) {
  try {
    return insetsString(view.safeAreaInsets());
  } catch (error) {
    return 'unavailable';
  }
}

function sceneOrientation(scene) {
  try {
    if (typeof scene.interfaceOrientation === 'function') {
      return orientationName(scene.interfaceOrientation());
    }
  } catch (error) {
  }
  return 'unavailable';
}

function objectSummary(object) {
  if (!object) {
    return 'nil';
  }
  try {
    return object.$className + '<' + object.handle + '>';
  } catch (error) {
    return String(object);
  }
}

function rootSummary(window) {
  try {
    const root = window.rootViewController();
    if (!root || root.handle.isNull()) {
      return 'root=nil';
    }
    let summary = 'root=' + objectSummary(root);
    try {
      summary += ' viewFrame=' + rectString(root.view().frame());
      summary += ' viewBounds=' + rectString(root.view().bounds());
      summary += ' viewSafeArea=' + safeAreaForView(root.view());
    } catch (error) {
    }
    try {
      if (typeof root.supportedInterfaceOrientations === 'function') {
        summary += ' supportedMask=' + root.supportedInterfaceOrientations();
      }
    } catch (error) {
    }
    return summary;
  } catch (error) {
    return 'root=error:' + error.message;
  }
}

function windowSummary(window, index) {
  let summary = '#' + index + ' ' + objectSummary(window);
  summary += ' hidden=' + callBool(window, 'isHidden');
  summary += ' key=' + callBool(window, 'isKeyWindow');
  summary += ' level=' + callDouble(window, 'windowLevel');
  try {
    summary += ' frame=' + rectString(window.frame());
    summary += ' bounds=' + rectString(window.bounds());
  } catch (error) {
  }
  summary += ' safeArea=' + safeAreaForView(window);
  summary += ' ' + rootSummary(window);
  return summary;
}

function enumerateArray(array, callback) {
  const count = Number(array.count());
  for (let index = 0; index < count; index++) {
    callback(array.objectAtIndex_(index), index);
  }
}

function enumerateSet(set, callback) {
  const enumerator = set.objectEnumerator();
  let index = 0;
  while (true) {
    const object = enumerator.nextObject();
    if (!object || object.handle.isNull()) {
      break;
    }
    callback(object, index);
    index++;
  }
}

globalThis.kayokoDumpWindows = function kayokoDumpWindows(label) {
  ObjC.schedule(ObjC.mainQueue, function () {
    log('DUMP ' + (label || '') + ' frontMost=' + frontMostOrientation() + ' screen=' + screenBounds());
    try {
      const application = ObjC.classes.UIApplication.sharedApplication();
      const scenes = application.connectedScenes();
      enumerateSet(scenes, function (scene, sceneIndex) {
        let sceneLine = 'scene#' + sceneIndex + ' ' + objectSummary(scene) + ' orientation=' + sceneOrientation(scene);
        try {
          sceneLine += ' activationState=' + scene.activationState();
        } catch (error) {
        }
        log(sceneLine);
        if (typeof scene.windows !== 'function') {
          return;
        }
        enumerateArray(scene.windows(), function (window, windowIndex) {
          log('  ' + windowSummary(window, windowIndex));
        });
      });
    } catch (error) {
      log('connectedScenes dump failed: ' + error.message);
    }
  });
};

ObjC.schedule(ObjC.mainQueue, function () {
  log('ready; call kayokoDumpWindows("portrait") or rotate and call kayokoDumpWindows("landscape")');
  globalThis.kayokoDumpWindows('initial');
});
}

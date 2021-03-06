/*
 *  rhodes
 *
 *  Copyright (C) 2008 Rhomobile, Inc. All rights reserved.
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
package com.rho.sync;

import com.xruby.runtime.lang.RubyBasic;
import com.xruby.runtime.lang.RubyBlock;
import com.xruby.runtime.lang.RubyClass;
import com.xruby.runtime.lang.RubyConstant;
import com.xruby.runtime.lang.RubyException;
import com.xruby.runtime.lang.RubyNoArgMethod;
import com.xruby.runtime.lang.RubyTwoArgMethod;
import com.xruby.runtime.lang.RubyVarArgMethod;
import com.xruby.runtime.lang.RubyRuntime;
import com.xruby.runtime.lang.RubyValue;
import com.xruby.runtime.builtin.RubyArray;
import com.xruby.runtime.builtin.RubyInteger;
import com.xruby.runtime.builtin.ObjectFactory;

/**
 * The Class SyncEngine.
 */
public class SyncEngine extends RubyBasic {

	/** The s thread. */
	private static SyncThread sThread = null;
	private static SyncNotifications sNotifications;
	
	
	// @RubyAllocMethod
	/**
	 * Alloc.
	 * 
	 * @param receiver the receiver
	 * 
	 * @return the sync engine
	 */
	public static SyncEngine alloc(RubyValue receiver) {
		return new SyncEngine(RubyRuntime.SyncEngineClass);
	}

	public static void setNotificationImpl(SyncNotifications pNotify ){
		sNotifications = pNotify;
	}
	public static SyncNotifications getNotificationImpl(){
		return sNotifications;
	}
	
	//public static RubyArray createArray() {
	//	return new RubyArray();
	//}
	//public static RubyHash createHash() {
	//	return ObjectFactory.createHash();
	//}
	public static RubyInteger createInteger(long val) {
		return ObjectFactory.createInteger(val);
	}
	//public static RubyString createString(String val) {
	//	return ObjectFactory.createString(val);
	//}
	
	// @RubyLevelMethod(name="dosync")
	/**
	 * Dosync.
	 * 
	 * @param receiver the receiver
	 * 
	 * @return the ruby value
	 */
	public static RubyValue dosync(RubyValue receiver) {
		wakeUp();
		return RubyConstant.QTRUE;
	}

	public static RubyValue login(RubyValue arg1, RubyValue arg2) {
		boolean bRes = SyncUtil.fetch_client_login(arg1.toString(), arg2.toString());
		return bRes ? createInteger(1L) : createInteger(0L); 
	}
	
	public static RubyValue logged_in() {
		boolean bRes = SyncUtil.logged_in();
		return bRes ? createInteger(1L) : createInteger(0L); 
	}
	
	public static RubyValue logout() {
		SyncUtil.logout();
		return RubyConstant.QNIL; 
	}
	
	public static RubyValue reset_sync_db() {
		SyncThread.setDbResetDelay(true);
		wakeUp();
		return RubyConstant.QNIL; 
	}

	public static RubyValue set_notification(RubyArray args) {
		
		if ( args.size() != 3 )
			throw new RubyException(RubyRuntime.ArgumentErrorClass, "in 'SyncEngine': wrong number of arguments (" + 
					args.length() + " for 3)");
        
		int nSourceID = args.get(0).toInt();
		String url = args.get(1).toStr();
		String params = "";
		if ( args.get(2) != RubyConstant.QNIL )
			params = args.get(2).toStr();
		
		sNotifications.setNotification(nSourceID, url, params);
		return RubyConstant.QNIL;
	}

	public static RubyValue clear_notification(RubyValue arg1) {
		int nSourceID = arg1.toInt();
		
		sNotifications.clearNotification(nSourceID);
		return RubyConstant.QNIL;
	}
	
	/**
	 * Inits the methods.
	 * 
	 * @param klass the klass
	 */
	public static void initMethods(RubyClass klass) {
		klass.defineMethod("initialize", new RubyNoArgMethod() {
			protected RubyValue run(RubyValue receiver, RubyBlock block) {
				return ((SyncEngine) receiver).initialize();
			}
		});
		klass.defineAllocMethod(new RubyNoArgMethod() {
			protected RubyValue run(RubyValue receiver, RubyBlock block) {
				return SyncEngine.alloc(receiver);
			}
		});
		klass.getSingletonClass().defineMethod("start", new RubyNoArgMethod() {
			protected RubyValue run(RubyValue receiver, RubyBlock block) {
				return SyncEngine.start(receiver);
			}
		});
		klass.getSingletonClass().defineMethod("stop", new RubyNoArgMethod() {
			protected RubyValue run(RubyValue receiver, RubyBlock block) {
				return SyncEngine.stop(receiver);
			}
		});
		klass.getSingletonClass().defineMethod("dosync", new RubyNoArgMethod() {
			protected RubyValue run(RubyValue receiver, RubyBlock block) {
				return SyncEngine.dosync(receiver);
			}
		});
		klass.getSingletonClass().defineMethod("lock_sync_mutex",
				new RubyNoArgMethod() {
					protected RubyValue run(RubyValue receiver, RubyBlock block) {
						return SyncEngine.lock_sync_mutex(receiver);
					}
				});
		klass.getSingletonClass().defineMethod("unlock_sync_mutex",
				new RubyNoArgMethod() {
					protected RubyValue run(RubyValue receiver, RubyBlock block) {
						return SyncEngine.unlock_sync_mutex(receiver);
					}
				});
		klass.getSingletonClass().defineMethod("login",
				new RubyTwoArgMethod() {
					protected RubyValue run(RubyValue receiver, RubyValue arg1, RubyValue arg2, RubyBlock block) {
						return SyncEngine.login(arg1,arg2);
					}
				});
		
		klass.getSingletonClass().defineMethod("logged_in",
				new RubyNoArgMethod() {
					protected RubyValue run(RubyValue receiver, RubyBlock block) {
						return SyncEngine.logged_in();
					}
				});
		
		klass.getSingletonClass().defineMethod("logout",
				new RubyNoArgMethod() {
					protected RubyValue run(RubyValue receiver, RubyBlock block) {
						return SyncEngine.logout();
					}
				});
		
		klass.getSingletonClass().defineMethod("trigger_sync_db_reset",
				new RubyNoArgMethod() {
					protected RubyValue run(RubyValue receiver, RubyBlock block) {
						return SyncEngine.reset_sync_db();
					}
				});

		klass.getSingletonClass().defineMethod("set_notification",
				new RubyVarArgMethod() {
					protected RubyValue run(RubyValue receiver, RubyArray args, RubyBlock block) {
						return SyncEngine.set_notification(args);
					}
				});
		klass.getSingletonClass().defineMethod("clear_notification",
				new RubyTwoArgMethod() {
					protected RubyValue run(RubyValue receiver, RubyValue arg1, RubyValue arg2, RubyBlock block) {
						return SyncEngine.clear_notification(arg1);
					}
				});
		
	}

	// @RubyLevelMethod(name="lock_sync_mutex")
	/**
	 * Lock_sync_mutex.
	 * 
	 * @param receiver the receiver
	 * 
	 * @return the ruby value
	 */
	public static RubyValue lock_sync_mutex(RubyValue receiver) {
		return RubyConstant.QFALSE;
	}

	// @RubyLevelMethod(name="start")
	/**
	 * Start.
	 * 
	 * @param receiver the receiver
	 * 
	 * @return the ruby value
	 */
	public static RubyValue start(RubyValue receiver) {
		// Initialize only one thread
		if (sThread == null) {
			sThread = new SyncThread();
		}
		return RubyConstant.QTRUE;
	}

	public static void wakeUp() {
		// Initialize only one thread
		if (sThread != null) {
			sThread.wakeUpSyncEngine();
		}
	}
	
	// @RubyLevelMethod(name="stop")
	/**
	 * Stop.
	 * 
	 * @param receiver the receiver
	 * 
	 * @return the ruby value
	 */
	public static RubyValue stop(RubyValue receiver) {
		if ( sThread != null ){
			sThread.quit();
			sThread = null;
		}
		
		return RubyConstant.QTRUE;
	}

	// @RubyLevelMethod(name="unlock_sync_mutex")
	/**
	 * Unlock_sync_mutex.
	 * 
	 * @param receiver the receiver
	 * 
	 * @return the ruby value
	 */
	public static RubyValue unlock_sync_mutex(RubyValue receiver) {
		return RubyConstant.QFALSE;
	}

	/**
	 * Instantiates a new sync engine.
	 * 
	 * @param c the c
	 */
	SyncEngine(RubyClass c) {
		super(c);
	}

	// @RubyLevelMethod(name="initialize")
	/**
	 * Initialize.
	 * 
	 * @return the sync engine
	 */
	public SyncEngine initialize() {
		return this;
	}
}

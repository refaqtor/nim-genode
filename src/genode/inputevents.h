/*
 * \brief  Input event structure
 * \author Norman Feske
 * \date   2006-08-16
 */

/*
 * Copyright (C) 2006-2017 Genode Labs GmbH
 *
 * This file is part of the Genode OS framework, which is distributed
 * under the terms of the GNU Affero General Public License version 3.
 */

#ifndef _INCLUDE__INPUT__EVENT_H_
#define _INCLUDE__INPUT__EVENT_H_

#include <base/output.h>
#include <input/keycodes.h>
#include <util/geometry.h>
#include <util/utf8.h>

namespace Input {

	typedef Genode::Codepoint Codepoint;

	struct Touch_id { int value; };

	/*
	 * Event attributes
	 */
	struct Press           { Keycode key; };
	struct Press_char      { Keycode key; Codepoint codepoint; };
	struct Release         { Keycode key; };
	struct Wheel           { int x, y; };
	struct Focus_enter     { };
	struct Focus_leave     { };
	struct Hover_leave     { };
	struct Absolute_motion { int x, y; };
	struct Relative_motion { int x, y; };
	struct Touch           { Touch_id id; float x, y; };
	struct Touch_release   { Touch_id id; };

	class Event;
}


struct Input::Event
{
		enum Type { INVALID, PRESS, RELEASE, REL_MOTION, ABS_MOTION, WHEEL,
		            FOCUS_ENTER, FOCUS_LEAVE, HOVER_LEAVE, TOUCH, TOUCH_RELEASE };

		Type _type = INVALID;

		struct Attr
		{
			union {
				Press_char      press;
				Release         release;
				Wheel           wheel;
				Absolute_motion abs_motion;
				Relative_motion rel_motion;
				Touch           touch;
				Touch_release   touch_release;
			};
		} _attr { };

		Event() { }
};

#endif /* _INCLUDE__INPUT__EVENT_H_ */

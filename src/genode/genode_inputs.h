#include "input_session/client.h"

struct Input::Binding
{
	typedef Input::Event::Type Event_type;
	typedef Input::Event::Attr Event_attr;
	static Event_type type(Input::Event &ev) { return ev._type; }
	static Event_attr attr(Input::Event &ev) { return ev._attr; }

	static Input::Event *event_buffer(Input::Session_client &client)
	{
		return client._event_ds.local_addr<Input::Event>();
	}
};

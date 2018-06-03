/*
 * Copyright (C) 2018 Genode Labs GmbH
 *
 * This file is part of the Genode OS framework, which is distributed
 * under the terms of the GNU Affero General Public License version 3.
 */


#ifndef _NIM__SIGNALS_H_
#define _NIM__SIGNALS_H_

#include <libc/component.h>
#include <base/signal.h>
#include <util/reconstructible.h>

/* Symbol for calling back into Nim */
extern "C" void nimHandleSignal(void *arg);

namespace Nim { struct SignalDispatcher; }

struct Nim::SignalDispatcher
{
	/**
	 * Pointer to a Nim type
	 */
	void *arg;

	/**
	 * Call Nim with dispatcher argument
	 */
	void handle_signal() {
		Libc::with_libc([this] () { nimHandleSignal(arg); }); }

	Genode::Signal_handler<SignalDispatcher> handler;

	SignalDispatcher(Genode::Entrypoint *ep, void *arg)
	: arg(arg), handler(*ep, *this, &SignalDispatcher::handle_signal) { }

	Genode::Signal_context_capability cap() {
		return handler; }
};

#endif

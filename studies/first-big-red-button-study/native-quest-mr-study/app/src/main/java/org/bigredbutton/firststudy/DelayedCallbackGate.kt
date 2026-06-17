package org.bigredbutton.firststudy

import java.util.concurrent.atomic.AtomicInteger

class DelayedCallbackGate {
  private val token = AtomicInteger(0)

  fun nextToken(): Int = token.incrementAndGet()

  fun invalidate(): Int = token.incrementAndGet()

  fun isCurrent(candidate: Int): Boolean = token.get() == candidate
}
